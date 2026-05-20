# Page dimensions in PDF points

Returns the width and height of `page` in PDF points (1 point = 1/72
inch). Accepts either a `pdfium_page` (preferred when you already have
one) or a `(doc, page)` pair (convenience for one-shot inspection).

## Usage

``` r
pdf_page_size(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A named numeric vector with elements `width` and `height`.

## Details

The returned dimensions are **media-box** dimensions in the page's
default (un-rotated) orientation. If the page has a non-zero rotation
(via the PDF `/Rotate` attribute or PDFium's runtime rotation),
`pdf_page_size()` does not swap width and height. Query the rotation
separately with
[`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)
if you need to know the on-screen orientation.

## See also

[`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)
for the rotation angle in degrees.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  pdf_page_size(doc, 1)
  pdf_doc_close(doc)
}
```
