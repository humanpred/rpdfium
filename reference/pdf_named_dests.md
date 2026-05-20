# Enumerate the document's named destinations

PDF authors can attach named "destinations" to specific page positions
(e.g. for cross-document links or programmatic navigation). Returns one
row per named destination with its name, target page, and the dest's
view/zoom parameters. Wraps `FPDF_CountNamedDests` / `FPDF_GetNamedDest`
/ `FPDFDest_GetDestPageIndex` / `FPDFDest_GetView` /
`FPDFDest_GetLocationInPage`.

## Usage

``` r
pdf_named_dests(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A tibble with columns:

- `name` character - the destination name, UTF-8.

- `page` integer - 1-based target page; `NA` when PDFium can't resolve
  it.

- `dest_view` character - the dest's view mode: one of `"xyz"`, `"fit"`,
  `"fith"`, `"fitv"`, `"fitr"`, `"fitb"`, `"fitbh"`, `"fitbv"`, or
  `"unknown"`.

- `dest_x`, `dest_y` numeric - the explicit (x, y) point for XYZ
  destinations and the line offset for FitH / FitV / FitBH / FitBV. `NA`
  when not specified by the destination.

- `dest_zoom` numeric - the explicit zoom for XYZ destinations, `NA`
  otherwise.
