# pdfium 0.1.0 — first CRAN submission

## Summary

`pdfium` is a new R package providing idiomatic bindings to Google's
PDFium PDF engine via Rcpp. It complements `pdftools` (Poppler) and
`qpdf` (QPDF) by exposing vector-path geometry — segment kinds,
control points, stroke / fill style, transformation matrices — that
no other R package surfaces. The Tier 2 surface (rendering, embedded
images, Form XObjects, clip paths, document metadata) is shipped
alongside the path API in this first release.

## Test environments

The R-CMD-check matrix in `.github/workflows/R-CMD-check.yaml`
covers:

* Ubuntu 24.04, R-release / R-devel / R-oldrel-1
* macOS-latest, R-release
* Windows-latest, R-release

`R CMD check --as-cran` locally on Ubuntu 24.04 with R 4.6.0:
0 ERRORs, 0 WARNINGs (1 environment-only WARNING about
`checkbashisms` is silenced when that tool is installed),
2 NOTEs detailed below.

## Expected NOTEs

* **"GNU make is a SystemRequirements"** — *not present yet, but
  may appear* on platforms where `inst/lib/libpdfium` is fetched at
  install time. The package declares `SystemRequirements: C++17,
  libpdfium (downloaded automatically at install time)` to make
  this explicit; the `configure` script downloads the matching
  bblanchon binary on demand and `cleanup` removes intermediate
  artefacts.

* **"Installed package size … Mb"** — the bundled `libpdfium`
  shared library is roughly 10–15 MB depending on platform. We
  download it at install time rather than shipping it in the
  source tarball, so the tarball itself is well under CRAN's
  5 MB limit (~1 MB).

## Network access at install time

The `configure` (POSIX) and `configure.win` (Windows) scripts
fetch the bblanchon `libpdfium` binary on first install. The
script:

* Honors `CRAN_PDFIUM_OFFLINE=1` as a hard opt-out for the CRAN
  build farm.
* Falls back to a prepopulated `inst/pdfium-binaries/` directory
  when one is present.
* Errors with a clear message — and a `configure` exit code that
  surfaces in `install.packages()` — when the network is
  unavailable and no fallback is present.

The pinned release URL and SHA-256 live in
`tools/pdfium-version.txt`; any change to the pin requires a new
ADR entry under `dev/decisions/`. The download URL points at
GitHub releases (`https://github.com/bblanchon/pdfium-binaries/...`)
which is in CRAN's allowlist of acceptable fetch sources for
`arrow`, `duckdb`, and other binary-heavy packages.

No network access is required to run the package after install.
Tests use only the bundled fixtures under `inst/extdata/fixtures/`;
examples either use those fixtures or are wrapped in
`if (nzchar(fixture)) { ... }` so they no-op when the package is
not yet installed.

## Reverse dependencies

This is a first submission; there are no reverse dependencies
yet. The internal consumer (`kmextract`, currently using
`pypdfium2` via reticulate) will switch to `pdfium` as a backend
after this release; its conformance suite has been run against
the v0.1.0 candidate.

## Examples runtime

Every documented function has a runnable example. The longest
single example runs in under 200 ms on a 2024 Linux laptop;
the full `R CMD check` example pass completes in well under
60 seconds. No example uses `\dontrun{}`; all use
`if (nzchar(system.file(...))) { ... }` to no-op when the
fixture is missing.

## CRAN policy compliance checklist

* [x] No writes outside `tempdir()` and the package install
      directory.
* [x] No network access during `R CMD check` (download is at
      install time only; tests use bundled fixtures).
* [x] No `\dontrun{}` examples.
* [x] Examples runtime < 5 s each; full pass < 60 s.
* [x] No `<<-` writes to `.GlobalEnv` or anywhere outside the
      package namespace.
* [x] No interactive prompts at install or load time.
* [x] All Suggests packages (`png`, `withr`, `lintr`, `styler`,
      `covr`, `knitr`, `rmarkdown`, `spelling`, `testthat`) are on
      CRAN and used via `requireNamespace()` where appropriate.

## Licence

Package code: MIT (with file LICENSE).
Bundled `libpdfium` binary: BSD-3-Clause. The combined provenance
and per-file attribution live in `LICENSE.md`.
