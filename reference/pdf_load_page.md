# Load a single page from an open PDF document

Returns a `pdfium_page` handle bound to its parent `doc`. The page is
garbage-collected with a finalizer that calls `FPDF_ClosePage`; call
[`pdf_close_page()`](https://humanpred.github.io/rpdfium/reference/pdf_close_page.md)
explicitly when you need deterministic release. The page keeps the
parent document alive for as long as the page is reachable, so it is
safe to drop your reference to `doc` while still holding a page.

## Usage

``` r
pdf_load_page(doc, page = 1L)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md).

- page:

  One-based page index. Must satisfy `1 <= page <= pdf_page_count(doc)`.

## Value

A `pdfium_page` object.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  page <- pdf_load_page(doc, 1)
  pdf_close_page(page)
  pdf_close(doc)
}
```
