
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# pdfium

<!-- badges: start -->

[![R-CMD-check](https://github.com/humanpred/rpdfium/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/humanpred/rpdfium/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/humanpred/rpdfium/branch/main/graph/badge.svg)](https://app.codecov.io/gh/humanpred/rpdfium)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/pdfium)](https://CRAN.R-project.org/package=pdfium)
[![Codecov test
coverage](https://codecov.io/gh/humanpred/rpdfium/graph/badge.svg)](https://app.codecov.io/gh/humanpred/rpdfium)
<!-- badges: end -->

`pdfium` provides idiomatic R bindings to [Google’s PDFium
engine](https://pdfium.googlesource.com/pdfium/) — the same library that
powers Chrome’s PDF viewer. It has two halves:

- a **read surface** that exposes vector-path geometry — stroke / fill /
  Bezier control points / transformation matrices — alongside text,
  fonts, images, annotations, form fields, attachments, signatures,
  structure tree, and rendering. The path geometry, in particular, no
  other CRAN package surfaces today.
- a **mutation surface** (opt-in via `readwrite = TRUE`) that lets you
  rotate / reorder / merge pages, draw fresh page objects, create and
  edit annotations, fill form fields, and add file attachments — then
  save the result.

## What it is for

- **Auditing** PDF figures (which lines, which colors, which fonts).
- **Extracting** curves from regulatory filings and scientific
  publications.
- **Building** PDF normalization pipelines that need geometry, not just
  text.
- **Filling** AcroForm fields programmatically and flattening the result
  for downstream tooling.
- **Authoring** programmatic PDFs from vector graphics, text, and
  annotations (think: figure callouts, table reports, annotated source
  documents). v0.1.0 ships paths / text in the 14 standard PDF fonts /
  annotations; image embedding and custom-font loading come in a later
  release.
- Anything you’d otherwise drop into Python with `pypdfium2`.

See
[`vignette("mutating-pdfs")`](https://humanpred.github.io/rpdfium/articles/mutating-pdfs.html)
for a walkthrough of the writer surface, and
[`vignette("comparison")`](https://humanpred.github.io/rpdfium/articles/comparison.html)
for how `pdfium` lines up against `pdftools`, `qpdf`, `magick`,
`tabulizer`, and `staplr`.

## Status

First CRAN release (`0.1.0`). The public API is documented on the
[pkgdown site](https://humanpred.github.io/rpdfium/) and exercised at
100% R coverage; architectural decisions for the release are recorded
under `dev/decisions/`.

## Installation

`pdfium` downloads its `libpdfium` binary from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
at install time. The pinned version lives in `tools/pdfium-version.txt`.
If your install runs without internet access, set `PDFIUM_OFFLINE=1` and
place the matching tarball under `inst/pdfium-binaries/` before
installing.

``` r
# Release version (once on CRAN):
install.packages("pdfium")

# Development version:
remotes::install_github("humanpred/rpdfium")
```

## Example

``` r
library(pdfium)

doc <- pdf_doc_open(system.file("extdata", "fixtures", "minimal.pdf",
  package = "pdfium"
))
pdf_page_count(doc)
pdf_doc_close(doc)
```

More examples ship in the vignettes
(`vignette("getting-started", package = "pdfium")`, etc.) and on the
[pkgdown site](https://humanpred.github.io/rpdfium/).

## License

`pdfium` is MIT-licensed. The bundled `libpdfium` binary is BSD-3-Clause
and is *not* distributed in the source tarball — see
[`LICENSE.md`](LICENSE.md) and
[`dev/decisions/ADR-003-binary-distribution.md`](dev/decisions/ADR-003-binary-distribution.md).
