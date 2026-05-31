# Create a new image page-object from JPEG bytes

Wraps `FPDFPageObj_NewImageObj` + `FPDFImageObj_LoadJpegFileInline` to
embed a JPEG into a page. The JPEG bytes are copied into the PDF at the
moment of creation (the "Inline" variant of PDFium's loader), so the
input is free to be garbage-collected immediately after the call
returns.

## Usage

``` r
pdf_image_new(page, jpeg, bounds = NULL)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md)
  (or a `pdfium_doc` with `page_num`). Parent doc must be readwrite.

- jpeg:

  Either a raw vector containing JPEG-encoded bytes or a character path
  to a JPEG file on disk. PNG / TIFF / other formats are not supported
  in v0.1.0; convert to JPEG with an external tool
  (`magick::image_write(..., format = "jpeg")` is the easy path) if
  needed.

- bounds:

  Optional length-4 numeric `c(left, bottom, right, top)` in PDF
  user-space points. When `NULL` (default), the image is placed at the
  origin at its natural pixel size in points (rarely what you want —
  pass an explicit `bounds`).

## Value

A `pdfium_obj` handle of `type = "image"`.

## Details

The new image is placed at the origin (0, 0) at its natural pixel size
in PDF user-space points (one unit per pixel). For a specific position
and size, pass `bounds = c(left, bottom, right, top)`; the wrapper
computes the transformation matrix that scales + translates the image
into that rectangle.

An image object's natural coordinate space is the unit square
`[0, 1] x [0, 1]`, and `bounds` is applied as the affine matrix that
scales and translates that square into the requested rectangle. To set
or change that matrix directly — instead of, or after, passing `bounds`
— call
[`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_set_matrix.md)
on the returned object. For example,

    img <- pdf_image_new(page, jpeg)                       # placed at origin
    pdf_obj_set_matrix(img, c(width, 0, 0, height, left, bottom))

reproduces `bounds = c(left, bottom, left + width, bottom + height)`.
Both the `bounds` path and
[`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_set_matrix.md)
use PDFium's generic `FPDFPageObj_SetMatrix`.

## See also

[`pdf_path_new()`](https://humanpred.github.io/rpdfium/reference/pdf_path_new.md),
[`pdf_rect_new()`](https://humanpred.github.io/rpdfium/reference/pdf_rect_new.md),
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md)
for sibling creators;
[`pdf_image_info()`](https://humanpred.github.io/rpdfium/reference/pdf_image_info.md),
[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
for the read side.

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- pdf_doc_new()
page <- pdf_page_new(doc, width = 612, height = 792)
jpeg_path <- system.file("img", "Rlogo.jpg", package = "jpeg")
if (nzchar(jpeg_path)) {
  pdf_image_new(page, jpeg_path,
                bounds = c(72, 600, 272, 700))
}
pdf_save(doc, tempfile(fileext = ".pdf"))
} # }
```
