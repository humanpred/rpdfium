# Insert a clip path into a page

Wraps `FPDFPage_InsertClipPath`, which inserts the clip path before the
page's content. PDFium does not take ownership of the clip path:
`clip_path` stays open, can be inserted into other pages, and is
released by
[`pdf_clip_path_close()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_close.md)
or when it is garbage-collected.

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
