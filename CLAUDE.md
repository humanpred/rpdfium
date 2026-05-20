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
- **CRAN target:** v0.1.0 ships to CRAN. Every change preserves
  CRAN-cleanliness.

## Layering — never bypass

    R user → R API (R/) → Rcpp glue (src/*.cpp) → PDFium C ABI → libpdfium.{so|dylib|dll}

- Public functions are snake_case and prefixed `pdf_*`.
- Internal Rcpp helpers are prefixed `cpp_*` and live in `src/`. Never
  re-export them.
- R wrappers validate inputs and own error messages. The C++ layer
  assumes arguments are already validated; it raises `Rcpp::stop` only
  for invariants that shouldn’t normally trip.

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
  an R `externalptr` with a C finalizer registered via
  `R_RegisterCFinalizerEx(..., TRUE)`.
- The finalizer is the **only** path that calls `FPDF_*Close*`. After it
  runs, it calls `R_ClearExternalPtr` so the pointer reads as NULL on
  subsequent access. This makes
  [`pdf_close()`](https://humanpred.github.io/rpdfium/reference/pdf_close.md)
  safely idempotent.
- Children (pages, page objects) hold an R-level reference to their
  parent (doc, page) so GC can’t reclaim the parent before the child.
  Always set the parent into the `prot` slot of the child’s externalptr.
- Automatic close on GC works — see `vignettes/architecture.Rmd`. But
  for large documents or platform-sensitive code (Windows file-handle
  blocking deletion), call
  [`pdf_close()`](https://humanpred.github.io/rpdfium/reference/pdf_close.md)
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
