# Convert PDF page-space points to bitmap pixel coordinates

Inverse of
[`pdf_bitmap_to_page()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_to_page.md).
Translates PDF user-space points to pixel positions on a `pdfium_bitmap`
(returned by
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)).
Wraps `FPDF_PageToDevice` with the render-geometry that produced the
bitmap pre-populated from the bitmap's attributes.

## Usage

``` r
pdf_bitmap_from_page(bitmap, x, y)
```

## Arguments

- bitmap:

  A `pdfium_bitmap` from
  [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md).

- x, y:

  Numeric vectors of PDF user-space coordinates. Recycled to a common
  length.

## Value

A two-column tibble with integer columns `x` and `y` in bitmap pixel
coordinates (origin at the bitmap's top-left).

## See also

[`pdf_bitmap_to_page()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_to_page.md)
for the inverse,
[`pdf_page_to_device()`](https://humanpred.github.io/rpdfium/reference/pdf_page_to_device.md)
for the underlying primitive.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  bmp <- pdf_render_page(doc, dpi = 72)
  # Map PDF page-space points (bottom-left origin) to bitmap pixels.
  pdf_bitmap_from_page(bmp, x = c(0, 72), y = c(0, 72))
  pdf_doc_close(doc)
}
```
