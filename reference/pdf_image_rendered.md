# Rendered image bitmap (page CTM applied)

Returns the embedded image rasterised with its page-level coordinate
transformation applied. Wraps `FPDFImageObj_GetRenderedBitmap`, which
honors the image's matrix and any mask. This is what a PDF viewer would
draw for the image, as opposed to
[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
which gives the source raster verbatim.

## Usage

``` r
pdf_image_rendered(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`.

## Value

A `pdfium_bitmap`, same shape contract as
[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md).

## See also

[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
for the source-pixel raster.
