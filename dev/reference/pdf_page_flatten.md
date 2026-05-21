# Flatten form fields and annotations into the page content stream

Wraps `FPDFPage_Flatten`. After flattening, form widgets and annotations
are baked into the page's content stream as static graphics — they no
longer exist as interactive objects. **This is irreversible**: there is
no `pdf_page_unflatten()`. Use this before saving a final-state PDF that
downstream consumers must not edit.

## Usage

``` r
pdf_page_flatten(page, mode = c("display", "print"))
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md).
  Parent doc must be readwrite.

- mode:

  Character scalar; one of `"display"` or `"print"`.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Two modes:

- `"display"` (default) — bake the on-screen appearance of every annot /
  widget.

- `"print"` — bake the print-time appearance instead.

Returns the page invisibly. The parent page's dirty mark is set so
[`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md)
picks up the change.

## See also

[`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md).
