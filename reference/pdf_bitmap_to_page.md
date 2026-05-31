# Convert bitmap pixel coordinates to PDF page-space points

Inverse of
[`pdf_bitmap_from_page()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_from_page.md).
Translates pixel positions in a `pdfium_bitmap` (returned by
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md))
to PDF user-space points on the source page. Wraps `FPDF_DeviceToPage`
with the render-geometry that produced the bitmap pre-populated from the
bitmap's attributes.

## Usage

``` r
pdf_bitmap_to_page(bitmap, x, y)
```

## Arguments

- bitmap:

  A `pdfium_bitmap` from
  [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md).
  Must carry render-geometry metadata (older
  [`pdf_render_page_with_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page_with_matrix.md)
  output doesn't).

- x, y:

  Numeric vectors of pixel positions on the bitmap. Recycled to a common
  length.

## Value

A two-column tibble with columns `x` and `y` in PDF user-space points
(origin at the page's bottom-left).

## See also

[`pdf_bitmap_from_page()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_from_page.md)
for the inverse,
[`pdf_device_to_page()`](https://humanpred.github.io/rpdfium/reference/pdf_device_to_page.md)
for the underlying primitive.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  bmp <- pdf_render_page(doc, dpi = 72)
  # Map two bitmap pixel positions back to PDF page-space points.
  pdf_bitmap_to_page(bmp, x = c(0, 100), y = c(0, 100))
  pdf_doc_close(doc)
}
```
