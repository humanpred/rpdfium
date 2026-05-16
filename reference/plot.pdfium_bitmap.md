# Plot a pdfium_bitmap

Draws the bitmap into the active graphics device at its source pixel
resolution, with `asp = 1` and zero margins so the image fills the
device without distortion. Internally a fresh plot window is opened
([`plot.new()`](https://rdrr.io/r/graphics/frame.html) +
[`plot.window()`](https://rdrr.io/r/graphics/plot.window.html)) and the
bitmap is drawn with
[`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html),
which natively accepts R's `nativeRaster` integer encoding.

## Usage

``` r
# S3 method for class 'pdfium_bitmap'
plot(x, interpolate = TRUE, ...)
```

## Arguments

- x:

  A `pdfium_bitmap` from
  [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)
  or
  [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
  /
  [`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/reference/pdf_image_rendered.md).

- interpolate:

  Passed through to
  [`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html).
  Default `TRUE`; set `FALSE` for pixel-exact (nearest-neighbour)
  display of small bitmaps.

- ...:

  Further arguments passed to
  [`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html).

## Value

Invisibly returns `x`. Called for the plotting side effect.

## Details

Base R does not ship a
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method for the
`nativeRaster` class, so calling
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) on a bare
`nativeRaster` integer matrix fails with "need finite 'xlim' values".
This S3 method fixes that for `pdfium_bitmap` objects specifically.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture) && interactive()) {
  bmp <- pdf_render_page(pdf_open(fixture), dpi = 96)
  plot(bmp)
}
```
