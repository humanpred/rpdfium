# Insert a clip path into a page

Wraps `FPDFPage_InsertClipPath`. After insertion the clip path is owned
by the page; the R-side `pdfium_clip_box` handle's externalptr is
cleared automatically so subsequent operations on it error cleanly via
`is_open()`.

## Usage

``` r
pdf_page_insert_clip_path(page, clip_path)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md)
  or
  [`pdf_page_new()`](https://humanpred.github.io/rpdfium/reference/pdf_page_new.md).
  Parent doc must be readwrite.

- clip_path:

  A `pdfium_clip_box` from
  [`pdf_clip_path_new()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_new.md).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_clip_path_new()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_new.md),
[`pdf_page_transform_with_clip()`](https://humanpred.github.io/rpdfium/reference/pdf_page_transform_with_clip.md).
