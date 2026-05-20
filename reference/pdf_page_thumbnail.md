# Page embedded thumbnail

Returns the bytes of a page's embedded `/Thumb` image stream, if the PDF
carries one. PDF authoring tools sometimes embed a low-resolution
preview alongside each page; readers can display that thumbnail without
rendering the full page. Wraps `FPDFPage_GetRawThumbnailData` and
`FPDFPage_GetDecodedThumbnailData`.

## Usage

``` r
pdf_page_thumbnail(page, page_num = 1L, decoded = TRUE)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

- decoded:

  If `TRUE` (default) returns the decoded bitmap bytes after PDFium has
  applied any stream filter (e.g. `/FlateDecode`). If `FALSE`, returns
  the raw filtered bytes — useful when a caller wants to save the
  thumbnail back to disk in its original encoded form, or pipe it
  through a different decoder.

## Value

A `raw` vector. Length zero when the page has no `/Thumb`.

## Details

Most PDFs produced by Cairo, LaTeX, or web tools do not embed thumbnails
— this function returns `raw(0)` in that common case.

## See also

[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)
to rasterize the full page instead.
