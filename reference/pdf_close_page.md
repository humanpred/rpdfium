# Close a page handle

Releases the underlying PDFium handle. Idempotent — calling
`pdf_close_page()` on an already-closed page is a no-op.

## Usage

``` r
pdf_close_page(page)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md).

## Value

Invisibly returns `page` with its underlying pointer marked closed.
