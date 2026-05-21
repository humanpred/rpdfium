# Load a single page from an open PDF document

Returns a `pdfium_page` handle bound to its parent `doc`. The page is
garbage-collected with a finalizer that calls `FPDF_ClosePage`; call
[`pdf_page_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_close.md)
explicitly when you need deterministic release. The page keeps the
parent document alive for as long as the page is reachable, so it is
safe to drop your reference to `doc` while still holding a page.

## Usage

``` r
pdf_page_load(doc, page_num = 1L)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md).

- page_num:

  One-based page index. Must satisfy
  `1 <= page_num <= pdf_page_count(doc)`.

## Value

A `pdfium_page` object.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  page <- pdf_page_load(doc, 1)
  pdf_page_close(page)
  pdf_doc_close(doc)
}
```
