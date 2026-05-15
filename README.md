<!-- README.md is generated from README.Rmd. Please edit that file. -->

# pdfium

<!-- badges: start -->
[![R-CMD-check](https://github.com/billdenney/rpdfium/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/billdenney/rpdfium/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/billdenney/rpdfium/branch/main/graph/badge.svg)](https://codecov.io/gh/billdenney/rpdfium)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN status](https://www.r-pkg.org/badges/version/pdfium)](https://CRAN.R-project.org/package=pdfium)
<!-- badges: end -->

`pdfium` provides idiomatic R bindings to
[Google's PDFium engine](https://pdfium.googlesource.com/pdfium/) — the
same library that powers Chrome's PDF viewer. It complements
[`pdftools`](https://docs.ropensci.org/pdftools/) and
[`qpdf`](https://CRAN.R-project.org/package=qpdf) by exposing **vector
path geometry** — stroke / fill / Bezier control points / transformation
matrices — which no other CRAN package surfaces today.

## What it is for

* Auditing PDF figures (which lines, which colors, which fonts).
* Extracting curves from regulatory filings and scientific publications.
* Building PDF normalization pipelines that need geometry, not just text.
* Anything you'd otherwise drop into Python with `pypdfium2`.

## Status

Pre-release. The 0.1.0 CRAN target is documented in
`docs/decisions/` and the project plan. The current public API is
documented at `pkgdown` and exercised at 100% R coverage.

## Installation

`pdfium` downloads its `libpdfium` binary from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
at install time. The pinned version lives in
`tools/pdfium-version.txt`. If your install runs without internet
access, set `PDFIUM_OFFLINE=1` and place the matching tarball under
`inst/pdfium-binaries/` before installing.

```r
# Development version
remotes::install_github("billdenney/rpdfium")
```

## Example

```r
library(pdfium)

doc <- pdf_open(system.file("extdata", "fixtures", "minimal.pdf",
                            package = "pdfium"))
pdf_page_count(doc)
pdf_close(doc)
```

More examples ship in the vignettes (`vignette("getting-started",
package = "pdfium")`, etc.) and on the
[pkgdown site](https://billdenney.github.io/rpdfium/).

## License

`pdfium` is MIT-licensed. The bundled `libpdfium` binary is BSD-3-Clause
and is *not* distributed in the source tarball — see
[`LICENSE.md`](LICENSE.md) and
[`docs/decisions/ADR-003-binary-distribution.md`](docs/decisions/ADR-003-binary-distribution.md).
