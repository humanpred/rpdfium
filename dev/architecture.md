# pdfium — contributor architecture

This document is the internal architecture reference for contributors.
A user-facing version (covering the same memory and binary-loading
sections plus worked examples) lives at
[`vignettes/architecture.Rmd`](../vignettes/architecture.Rmd).

## Four-layer model

```
R user
  │
  ▼
R API (R/)                  pdf_doc_open, pdf_doc_close, pdf_page_count, ...
  │                         S3 classes: pdfium_doc, pdfium_page, pdfium_obj
  ▼
Rcpp glue (src/*.cpp)       cpp_* helpers; one .cpp per logical group
  │                         (init, document, page, paths, text, ...)
  ▼
PDFium C ABI                FPDF_*, FPDFPage_*, FPDFPath_*, FPDFText_*, ...
  │                         (public/fpdfview.h and siblings)
  ▼
libpdfium.{so|dylib|dll}    downloaded from bblanchon/pdfium-binaries
                            at install time per ADR-003
```

Each layer has one job and one consumer. The R API validates inputs
and owns user-visible errors. The Rcpp glue assumes inputs are
already validated and translates PDFium return values into R-native
types. The C ABI is what it is — we don't rewrap it inside C++. The
shared library is loaded once per session.

## Memory model — what every contributor must know

Read [ADR-005](decisions/ADR-005-memory-model.md) first. Summary:

1. Every PDFium handle (`FPDF_DOCUMENT`, `FPDF_PAGE`, etc.) lives
   behind an R `externalptr` with a C finalizer registered via
   `R_RegisterCFinalizerEx(ptr, finalizer, TRUE)`.
2. The finalizer is the **only** path that calls `FPDF_*Close*`.
3. After closing, the finalizer calls `R_ClearExternalPtr` so the
   pointer reads as NULL on subsequent access. This makes
   user-visible `pdf_doc_close()` and equivalents safely idempotent.
4. Children (pages, page objects) hold an R-level reference to their
   parent (doc, page) through the `prot` slot of the child
   externalptr. R's GC keeps the parent alive while a child exists.
5. PDFium's library lifecycle (`FPDF_InitLibraryWithConfig` /
   `FPDF_DestroyLibrary`) runs in `.onLoad` / `.onUnload`.

The auto-close test in `tests/testthat/test-document.R` is
load-bearing — don't remove it.

## Binary-loading sequence

```
package install
  ├─ configure (POSIX) / configure.win (Windows)
  │     ├─ Rscript tools/download-pdfium.R <pkg-root>
  │     │     └─ download bblanchon archive
  │     │        for the pinned version (tools/pdfium-version.txt)
  │     │        and the current OS/arch, extract to:
  │     │            inst/include/   public headers
  │     │            inst/lib/       libpdfium.{so|dylib|.lib}
  │     │            inst/bin/       pdfium.dll (Windows)
  │     └─ POSIX: template src/Makevars from src/Makevars.in with
  │        the resolved absolute paths and an RPATH
  │            ($ORIGIN/../lib on Linux,
  │             @loader_path/../lib on macOS)
  └─ R CMD INSTALL ... builds src/pdfium.so linking against libpdfium

package load (every R session)
  ├─ library(pdfium)
  ├─ R/zzz.R .onLoad fires
  ├─ Rcpp's useDynLib loads src/pdfium.so
  │     (which transitively loads libpdfium via RPATH)
  └─ .onLoad calls cpp_init_library() → FPDF_InitLibraryWithConfig
```

## Common pitfalls

- **Windows DLL ordering.** `FPDF_InitLibraryWithConfig` must run
  after `pdfium.dll` is loaded. R's loader handles this if the DLL
  sits in `inst/bin/` and we let `useDynLib` pull it in; manual
  `library.dynam()` calls in `.onLoad` would race the package's own
  DLL.
- **macOS install_name.** Without the `@loader_path/../lib` RPATH,
  installed `pdfium.so` looks for `libpdfium.dylib` at the build-time
  absolute path, which doesn't exist on the user's machine. The
  template in `src/Makevars.in` handles this.
- **Linux RPATH.** `$ORIGIN/../lib` is shell-expanded by `make`
  unless the dollar is escaped: `$$ORIGIN/../lib`. The `configure`
  script writes the double dollar literally.
- **GC order.** A finalizer running while the PDFium library has been
  destroyed crashes. We register finalizers as `onexit = TRUE` so
  they run during R session shutdown *before* `.onUnload` destroys
  the library.
- **Parallel testthat + valgrind.** They don't compose. `valgrind.yaml`
  and `cpp-asan.yaml` set `TESTTHAT_PARALLEL=false` to force serial
  tests under instrumentation.

## PDFium bump procedure

When updating `tools/pdfium-version.txt`:

1. Update the file to the new release tag exactly as bblanchon ships
   it (e.g. `chromium/7210`).
2. Rebuild fixtures via `Rscript tools/build-fixtures.R`.
3. Run the full test suite locally: `devtools::test()`.
4. Run `devtools::check()` and confirm no new warnings or notes.
5. Run the conformance test against pypdfium2 if accessible (Phase 1+).
6. If the new release ships under a different license combination,
   update `LICENSE.md` to reflect it.
7. Add a `NEWS.md` entry under "(development version)" describing
   the bump and any user-visible behavioural change.
8. Open a PR with the bump as a standalone commit so reviewers can
   bisect easily.

## Fixture-rebuild pipeline

Test PDFs under `inst/extdata/fixtures/` are
reproducible-by-construction:

```
tools/build-fixtures.R
  ├─ uses base R / Cairo / survival / survminer to render each
  │  fixture deterministically (no random seeds, no system fonts)
  └─ writes to inst/extdata/fixtures/<name>.pdf
```

CI re-runs this script and confirms the produced bytes match the
checked-in copy (or, less brittly, that the hash matches). If a
font substitution drift breaks the byte match, we either update the
fixture or pin a font in the build script.

## CI topology

See [ADR-007](decisions/ADR-007-ci-and-coverage.md). Eight workflows;
four are gates (`R-CMD-check`, `coverage`, `lint`, `pre-commit`).
`valgrind` and `cran-check` run weekly. `cpp-asan` is advisory.
`pkgdown` only deploys on tag pushes.

## Where decisions live

| Topic | Source of truth |
|---|---|
| Why we picked Rcpp + C++17 + S3 | `dev/decisions/ADR-001-language-stack.md` |
| License composition | `dev/decisions/ADR-002-license.md` + `LICENSE.md` |
| How the binary gets onto user machines | `dev/decisions/ADR-003-binary-distribution.md` |
| API naming and reserved signatures | `dev/decisions/ADR-004-api-style.md` |
| `pdfium_doc` lifetime semantics | `dev/decisions/ADR-005-memory-model.md` |
| When and how to bump PDFium | `dev/decisions/ADR-006-pdfium-pin.md` |
| Why coverage is gated at 100% R | `dev/decisions/ADR-007-ci-and-coverage.md` |
| CRAN-targeting choices | `dev/decisions/ADR-008-cran-targeting.md` |

Material new decisions get their own ADR. See
`dev/decisions/README.md` for the policy.
