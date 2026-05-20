# pdfium

`pdfium` provides idiomatic R bindings to [Google’s PDFium
engine](https://pdfium.googlesource.com/pdfium/) — the same library that
powers Chrome’s PDF viewer. It complements
[`pdftools`](https://docs.ropensci.org/pdftools/) and
[`qpdf`](https://CRAN.R-project.org/package=qpdf) by exposing **vector
path geometry** — stroke / fill / Bezier control points / transformation
matrices — which no other CRAN package surfaces today.

## What it is for

- Auditing PDF figures (which lines, which colors, which fonts).
- Extracting curves from regulatory filings and scientific publications.
- Building PDF normalization pipelines that need geometry, not just
  text.
- Anything you’d otherwise drop into Python with `pypdfium2`.

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
                            package = "pdfium"))
pdf_page_count(doc)
pdf_doc_close(doc)
```

More examples ship in the vignettes
([`vignette("getting-started", package = "pdfium")`](https://humanpred.github.io/rpdfium/articles/getting-started.md),
etc.) and on the [pkgdown site](https://humanpred.github.io/rpdfium/).

## License

`pdfium` is MIT-licensed. The bundled `libpdfium` binary is BSD-3-Clause
and is *not* distributed in the source tarball — see
[`LICENSE.md`](https://humanpred.github.io/rpdfium/LICENSE.md) and
[`dev/decisions/ADR-003-binary-distribution.md`](https://humanpred.github.io/rpdfium/dev/decisions/ADR-003-binary-distribution.md).
