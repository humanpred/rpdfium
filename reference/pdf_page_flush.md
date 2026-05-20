# Force-flush a page's pending content edits

Runs PDFium's `FPDFPage_GenerateContent` on `page`, persisting every
page-object / annotation / form-field mutation that has accumulated
since the page was loaded into the page's content stream. The render
paths
([`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md),
[`pdf_render_page_with_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page_with_matrix.md))
and
[`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md)
all flush automatically; calling `pdf_page_flush()` explicitly is useful
when a downstream tool peeks at the in-memory PDF (e.g. via
[`pdf_save_to_raw()`](https://humanpred.github.io/rpdfium/reference/pdf_save_to_raw.md)
with intermediate inspection) and you want the latest edits to be
visible without round-tripping through disk.

## Usage

``` r
pdf_page_flush(page)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md).

## Value

The input `page`, invisibly.

## Details

The function is idempotent: calling it on a clean page is a no-op. After
the flush the page is removed from the document's dirty-pages set, so
subsequent renders won't redundantly re-flush.

## See also

[`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md),
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md).
