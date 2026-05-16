# Decoded image bitmap

Returns the embedded image's decoded pixel buffer as a
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)-compatible
`pdfium_bitmap`. Wraps `FPDFImageObj_GetBitmap`, which decodes the
source stream but does not apply the page's coordinate transformation -
the bitmap is the raw source raster, oriented in the image's own
coordinate system.

## Usage

``` r
pdf_image_bitmap(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`.

## Value

A `pdfium_bitmap` (integer matrix with class
`c("pdfium_bitmap", "nativeRaster")`, `dim = c(height, width)`) carrying
attributes `dpi = NA_real_` (the source image's DPI is in
[`pdf_image_info()`](https://humanpred.github.io/rpdfium/reference/pdf_image_info.md)
but doesn't apply to this raw raster), `source_page`, `source_path`, and
`rotation_applied = 0L`. Use
[`as.array.pdfium_bitmap()`](https://humanpred.github.io/rpdfium/reference/as.array.pdfium_bitmap.md)
/
[`as.raster.pdfium_bitmap()`](https://humanpred.github.io/rpdfium/reference/as.raster.pdfium_bitmap.md)
to convert to other shapes.

## See also

[`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/reference/pdf_image_rendered.md)
for the CTM-applied rendering,
[`pdf_image_data()`](https://humanpred.github.io/rpdfium/reference/pdf_image_data.md)
for the raw embedded stream bytes.
