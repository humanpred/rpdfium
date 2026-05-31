# Embed a bitmap as an image page-object

Creates a blank image page-object on `page`, attaches the pixel data in
`bitmap` to it, optionally sets the placement matrix from `bounds`, and
inserts the result into the page. Companion to
[`pdf_image_new()`](https://humanpred.github.io/rpdfium/reference/pdf_image_new.md)
(the JPEG path) for the raster path. The returned handle is a
`pdfium_obj` of type `"image"` like every other page-level image.

## Usage

``` r
pdf_image_new_from_bitmap(page, bitmap, bounds = NULL)
```

## Arguments

- page:

  A `pdfium_page` or `pdfium_doc` opened with `readwrite = TRUE`.

- bitmap:

  A `pdfium_image_buffer` from
  [`pdf_bitmap_new()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_new.md).

- bounds:

  Optional length-4 numeric vector `c(left, bottom, right, top)` in PDF
  user-space points. When supplied, the image is positioned at those
  bounds via `FPDFPageObj_SetMatrix` (the same generic setter
  [`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_set_matrix.md)
  exposes). When `NULL`, the image sits at the unit square
  (`[0,1] × [0,1]`) and the caller is responsible for setting a
  placement matrix via
  [`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_set_matrix.md)
  afterwards.

## Value

A `pdfium_obj` of type `"image"`.

## Details

The bitmap is copied into the page-object — callers are free to
[`pdf_bitmap_close()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_close.md)
the `pdfium_image_buffer` after this call returns. (Without the copy,
the bitmap's pixel buffer would dangle once R garbage-collected the
bitmap.)

## See also

[`pdf_image_new()`](https://humanpred.github.io/rpdfium/reference/pdf_image_new.md)
for the JPEG-bytes path,
[`pdf_bitmap_new()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_new.md)
for the bitmap constructor,
[`pdf_image_set_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_set_bitmap.md)
for the attach-only step.

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- pdf_doc_new()
page <- pdf_page_new(doc, width = 612, height = 792)
bm <- pdf_bitmap_new(32L, 32L, alpha = TRUE)
pdf_bitmap_fill_rect(bm, 0L, 0L, 32L, 32L, 0xFFFF0000)
pdf_image_new_from_bitmap(page, bm, bounds = c(72, 600, 200, 700))
pdf_bitmap_close(bm)
pdf_save(doc, tempfile(fileext = ".pdf"))
} # }
```
