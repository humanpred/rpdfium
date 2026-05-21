# Create a new, empty PDF document

Wraps `FPDF_CreateNewDocument`. The returned `pdfium_doc` has no pages —
add some with
[`pdf_page_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_new.md)
before saving. Always returned with `readwrite = TRUE`; there is no
read-only new document.

## Usage

``` r
pdf_doc_new()
```

## Value

A `pdfium_doc` with zero pages.

## See also

[`pdf_page_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_new.md)
to add a page;
[`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md)
to persist the result.

## Examples

``` r
doc <- pdf_doc_new()
pdf_page_new(doc, 1, 612, 792)
#> <pdfium_page [open] page 1 of <new>>
tmp <- tempfile(fileext = ".pdf")
pdf_save(doc, tmp)
pdf_doc_close(doc)
```
