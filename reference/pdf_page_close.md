# Close a page handle

Releases the underlying PDFium handle. Idempotent — calling
`pdf_page_close()` on an already-closed page, including one that
[`pdf_doc_close()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_close.md)
closed with its document, is a no-op.

## Usage

``` r
pdf_page_close(page)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md).

## Value

Invisibly returns `page` with its underlying pointer marked closed.
