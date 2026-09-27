# CLAUDE.md — Working conventions for AI contributors

This file is the durable contract between Claude (and any other AI
coding agent) and the `pdfium` R package. Read it before your first edit
on a fresh worktree. Update it when you discover a convention worth
recording.

## Package identity

- **Package name:** `pdfium` (no `r` prefix; matches
  `magick`/`xml2`/`httr`).
- **Repository name:** `rpdfium` on GitHub.
- **License:** MIT (package) + BSD-3-Clause (bundled PDFium binary).
- **Distribution:** no CRAN release is planned (ADR-026). Binaries ship
  through r-universe and source through GitHub; see
  `dev/r-universe-evaluation.md`.
- **Quality bar:** CRAN quality, kept from ADR-008. Every change keeps
  `R CMD check --as-cran` clean, the source tarball small (PDFium is
  downloaded at install time, never vendored), tests and examples free
  of network access, examples at 5 s or less, writes inside
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), no unjustified
  `\dontrun{}`, and R coverage at 100%.

## Scope — wrap PDFium, don’t invent helpers

The package’s job is to expose Google’s PDFium C API to R idiomatically.
Every public function should ultimately call into PDFium (perhaps via a
chain of internal helpers) or be unambiguously tied to PDF-format
concepts
([`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
parses the PDF date-string format).

What does **not** belong:

- Filesystem walking
  ([`list.files()`](https://rdrr.io/r/base/list.files.html) loops over
  `pdf_doc_*`).
- Network plumbing beyond what PDFium itself does. `pdf_doc_open(path)`
  accepting a URL is fine — the URL becomes raw bytes which go straight
  into PDFium’s `FPDF_LoadMemDocument64`. A function whose body is
  mostly `httr2::request(...)` is not.
- Bulk / batch wrappers (“apply this PDFium function to every file in a
  folder”). Users have `lapply` and `purrr` for that.
- Cross-PDF analysis (“compare these two PDFs”). Out of scope.

When in doubt, ask: *what PDFium symbol does this wrap?* If the answer
is “none — it’s a convenience over base R”, the function belongs in user
code or a separate utility package, not here.

This is recorded as a deletion-justification in `NEWS.md` for the
`pdf_dir_summary` / `pdf_doc_open_url` retraction. Future contributors
shouldn’t re-add functions whose job is to glue base R primitives
together around pdfium calls.

## Layering — never bypass

    R user → R API (R/) → Rcpp glue (src/*.cpp) → PDFium C ABI → libpdfium.{so|dylib|dll}

- Public functions are snake_case and prefixed `pdf_*`.
- Internal Rcpp helpers are prefixed `cpp_*` and live in `src/`. Never
  re-export them.
- R wrappers validate inputs and own error messages. The C++ layer
  assumes arguments are already validated; it raises `Rcpp::stop` only
  for invariants that shouldn’t normally trip.

## Naming — accessors vs. verbs

See
[ADR-019](https://humanpred.github.io/rpdfium/dev/decisions/ADR-019-naming-conventions.md)
for the rationale and the full table. The short version, in priority
order:

1.  **Accessors are object-first.** If the function reads or sets an
    attribute of a specific PDFium object (doc, page, obj, path, text,
    image, annot, form_field, attachment, signature, bookmark, …), the
    name starts with the object’s short name:

        pdf_<object>_<attribute>()          # reader
        pdf_<object>_set_<attribute>()      # setter
        pdf_<object>_new()                  # constructor (fresh instance)
        pdf_<object>_open()                 # constructor (from external source)
        pdf_<object>_load()                 # constructor (by index from parent)
        pdf_<object>_close()                # release handle
        pdf_<object>_delete()               # remove from parent

    Examples: `pdf_doc_open`, `pdf_doc_close`, `pdf_doc_info`,
    `pdf_page_load`, `pdf_page_close`, `pdf_page_size`,
    `pdf_page_set_rotation`, `pdf_obj_bounds`, `pdf_path_segments`.

2.  **Verbs / actions are verb-first.** If the function performs an
    action — render, extract, merge, parse, search — that doesn’t
    naturally belong to one object’s attribute namespace, the name
    starts with the verb:

        pdf_<verb>()
        pdf_<verb>_<modifier>()
        pdf_<verb>_<object>()              # plural object name when the
                                           # verb acts on a collection

    Examples: `pdf_render_page`, `pdf_render_to_png`,
    `pdf_extract_paths`, `pdf_docs_merge`, `pdf_n_up`, `pdf_parse_date`.

3.  **At-point hit testers** use a spatial-query suffix:

        pdf_<thing>_at_point(parent, x, y, ...)

    Examples: `pdf_link_at_point`, `pdf_link_annot_at_point`,
    `pdf_form_field_at_point`, `pdf_text_char_at_point`.

When you add a function, pick the convention by asking: *does this
function read or set an attribute of one PDFium object?* If yes,
object-first. If it performs an action across multiple objects or is a
pure utility, verb-first.

## Argument validation — use `checkmate`

See
[ADR-010](https://humanpred.github.io/rpdfium/dev/decisions/ADR-010-checkmate-for-argument-validation.md)
for the rationale. The short version:

- **All new R-side validation** must use `checkmate::assert_*` (e.g.
  `assert_count`, `assert_string`, `assert_number`, `assert_matrix`,
  `assert_multi_class`). Do **not** hand-roll
  `is.numeric(x) && length(x) == 1L && ...` chains — they trip
  `cyclocomp_linter` and produce inconsistent error messages.
- Reach for `assert_*` (the
  [`stop()`](https://rdrr.io/r/base/stop.html)-raising form), not
  `check_*` / `test_*`. Keeps error semantics aligned with the rest of
  the API.
- pdfium-specific assertions that have no single-call checkmate
  equivalent (e.g. “must be `pdfium_page` OR `pdfium_doc`”, “must be an
  open page handle”) get a small wrapper in `R/utils.R` that itself
  calls `checkmate::assert_*` for the shape parts.
- In tests, target the argument-name portion of checkmate’s standard
  message (e.g. `regexp = "Assertion on 'x' failed"`) rather than
  matching exact phrasing — checkmate’s wording can shift between
  versions without churning the test suite.

## Memory model — the rule that bites if you forget it

- Every PDFium handle (`FPDF_DOCUMENT`, `FPDF_PAGE`, etc.) lives behind
  an R `externalptr`. Every handle with a finalizer is in one registry,
  `src/handle_registry.{h,cpp}` (ADR-024, ADR-025, ADR-028, ADR-031,
  ADR-032): annotation contexts, pages, fonts, XObjects and annotation
  page-objects under their document; documents,
  [`pdf_clip_path_new()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_new.md)
  clip paths and bitmaps under the library.
- One mint and one release path per kind: `make_*_handle()` alone
  creates the externalptr (finalizer attached, handle registered), and
  `release_*_handle()` alone closes and clears it — the finalizer, the
  explicit `pdf_*_close()` /
  [`pdf_annot_delete()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_delete.md)
  and the owner’s release all call it, so every close is idempotent.
  Never close a handle `make_*_handle()` made anywhere else.
- The finalizer is the R function `finalize_handle()` (ADR-031), which
  `make_handle()` alone attaches. It calls into the shared library only
  while the library is loaded, looking the routine up by name each time,
  and the library releases only handles its own registry holds, so a
  handle may outlive
  [`unloadNamespace()`](https://rdrr.io/r/base/ns-load.html),
  `detach(unload = TRUE)` or a
  [`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html)
  reload. Never attach a C finalizer (`R_RegisterCFinalizerEx`): R calls
  it even after the library is unloaded, and `test-finalizer.R` fails on
  one.
- Owners release their handles first:
  [`pdf_doc_close()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_close.md)
  closes the document’s annotations, pages, fonts and XObjects before
  `FPDF_CloseDocument`, and `cpp_destroy_library()` closes every
  document, clip path and bitmap before `FPDF_DestroyLibrary`. Those
  handles then read as closed.
- Registry entries are weak: the externalptr `SEXP`s sit in C++
  containers R does not scan, and the finalizer removes each one from
  the registry before R frees it, so an unreachable handle is still
  collected promptly.
- A document loaded from memory reads from a raw vector in its handle’s
  `prot` slot: PDFium reads the bytes until the document is closed, and
  R frees the vector only after the handle.
- Children pin their immediate owner in `prot` (a page its document, an
  annotation its page, a page-object its page, annotation or form, a
  clip path its page-object), and both `validate_handle()` in C++ and
  `is_open()` in R walk the whole chain (ADR-029): a handle is refused
  once any owner is closed.
- Automatic close on GC works — see `vignettes/architecture.Rmd`. But
  for large documents or platform-sensitive code (Windows file-handle
  blocking deletion), call
  [`pdf_doc_close()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_close.md)
  explicitly.

## Testing — must be safe under parallel execution

- `DESCRIPTION` sets `Config/testthat/parallel: true`. Every `test-*.R`
  runs in its own subprocess.
- **Never** assume a specific test-file order.
- **Never** share mutable state across files. Use `withr::local_*` /
  [`withr::defer()`](https://withr.r-lib.org/reference/defer.html) for
  cleanup.
- Helpers go in `tests/testthat/helper-*.R` (sourced into every worker).
- Setup that’s *truly* once-per-worker goes in `tests/testthat/setup.R`.
- Fixtures load through `fixture_path("name")` (see
  `helper-fixtures.R`). Never embed a hardcoded path.
- valgrind and ASan runs override `Config/testthat/parallel` to false —
  don’t write tests that *require* parallelism to pass.

## Code style

- R: tidyverse style enforced by `lintr` and `styler`. Run
  `pre-commit run --all-files` before pushing.
- C++: C++17, no exceptions across the C ABI boundary (translate to
  `Rcpp::stop`). Header-then-source order, `#include "fpdfview.h"`
  first.
- Never write `<<-`. Never write `assign(..., envir = .GlobalEnv)`.
- Comments: only when the *why* isn’t obvious. Don’t restate what code
  says. Don’t reference PR numbers or “added for the X flow” — that
  belongs in commit messages.

## Files an AI must always update together

| When you change… | Also update |
|----|----|
| Public API in `R/*.R` | `NAMESPACE` (via `devtools::document()`), tests, vignettes |
| `src/*.cpp` Rcpp exports | `R/RcppExports.R`, `src/RcppExports.cpp` (via [`Rcpp::compileAttributes()`](https://rdrr.io/pkg/Rcpp/man/compileAttributes.html)) |
| `DESCRIPTION` `Imports:` | `NAMESPACE` `import*` directives |
| `tools/pdfium-version.txt` | `NEWS.md`, conformance test suite re-run |
| Architectural choice | A new ADR under `dev/decisions/`, indexed in `dev/decisions/README.md` |
| Bundled binary distribution | `LICENSE.md` “Bundled binary distribution” section |
| Any of `dev/upstream-feature-survey.md`, `dev/r-pdf-ecosystem-survey.md`, `dev/pdfium-api-review.md` | The “Provenance” block at the top of that file — survey date, commit hashes, CRAN versions, refresh-command snippet. Drift in these blocks defeats the purpose of having them. |

## Parallel sub-agents — isolate the build directory, prefer load_all

When dispatching multiple sub-agents via the `Agent` tool to work on
different files in parallel, **always pass `isolation: "worktree"`**.
Without it, every agent shares the same `src/`, `src/*.o`, `src/*.so`,
and any install target (`~/R/.../pdfium/` or a shared
`/tmp/rlib_pdfium/`). When each agent’s verify step runs
`find src -name "*.o" -delete && ... R CMD INSTALL`, the agents clobber
one another’s intermediate builds and the install location, and
individual runs cycle without finishing — burning CPU while making no
net progress.

`isolation: "worktree"` puts each agent in its own `git worktree`
checkout under a temporary path. The Agent tool returns the worktree
path + branch when the agent finishes; merge that branch back into your
working branch at the end.

Inside the agent prompt, prefer `devtools::load_all(".")` and
`devtools::test()` over `R CMD INSTALL --library=...`. Reasons:

- `load_all()` compiles in-place under the package’s `src/` and loads
  into the running R session without writing to any system library. Much
  faster, and there’s no shared install target to collide on.
- `devtools::test()` implicitly calls `load_all()` first, so a single
  command both rebuilds and runs the requested test filter.
- `covr::package_coverage(type = "tests")` does its own coverage-
  instrumented build under a private prefix; it does NOT need a separate
  `R CMD INSTALL` step. Just run it directly.
- `devtools::check()` is the right last-mile gate (it runs
  `R CMD check --as-cran`), but reserve it for the final verification
  pass on the main worktree — it’s slow and not what you want inside a
  per-file coverage loop.

`R CMD INSTALL` is only needed when the package’s installed copy must be
visible to *another* process — e.g.
[`lintr::lint_package()`](https://lintr.r-lib.org/reference/lint.html)
reading the installed namespace from
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html), or a fresh R
subprocess loading the package via
[`library(pdfium)`](https://github.com/humanpred/rpdfium). Coverage,
tests, and `load_all` do not.

Bash hint: `LD_LIBRARY_PATH="$(pwd)/inst/lib"` is the prefix any
`Rscript -e ...` invocation needs so the bundled `libpdfium.so`
(unpacked into `inst/lib/` by the install-time
`tools/download-pdfium.R`) resolves at dyn.load time.

## Git / GitHub workflow

- Never push to `main`. Open a PR from a feature branch.
- Branch naming: `claude/<short-topic>` for AI-authored branches,
  `feature/<topic>` for human-authored.
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `docs:`,
  `chore:`, `test:`, `refactor:`, `perf:`, `ci:`, `build:`, `style:`,
  `revert:`.
- **The `gh` CLI is read-only on this machine.** Do not run
  `gh pr create`, `gh pr edit`, `gh pr merge`, `gh issue create`,
  `gh issue comment`, `gh release create`, or any `gh api` call with a
  non-GET method. After pushing, give the user the suggested title and
  body so they can open the PR themselves.

## Pre-commit hooks

Install once per fresh clone or worktree before your first commit:

``` sh
pip install --user pre-commit
pre-commit install
pre-commit install --hook-type pre-push
```

The `pre-commit` stage runs fast checks (lint, parsable, format). The
`pre-push` stage adds full lint, roxygen regen, and parallel tests. CI
re-runs the full configuration so a missed local install still gets
caught — but local installation gives the fastest feedback.

## When in doubt

- Read `vignettes/architecture.Rmd` for the four-layer model and the
  memory-model contract.
- Read the ADRs under `dev/decisions/`. They are the record of every
  intentional choice — supersede with a new ADR, don’t edit accepted
  ones.
- The plan file at
  `/home/bill/.claude/plans/pdfium-r-package-peaceful-frog.md` captures
  the full project roadmap.
