# Plot a pdfium_bitmap

Draws the bitmap into the active graphics device at its source pixel
resolution. Internally the bitmap is converted to a 3-D numeric array
(the format
[`png::writePNG()`](https://rdrr.io/pkg/png/man/writePNG.html) and the R
graphics engine both consume cleanly) and drawn with
[`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html) on a
fresh `grid` page.

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
  [`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html).
  Default `TRUE`; set `FALSE` for pixel-exact (nearest-neighbour)
  display of small bitmaps.

- ...:

  Further arguments passed to
  [`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html).

## Value

Invisibly returns `x`. Called for the plotting side effect.

## Details

We go through `as.array(x)` to a 3-D `c(H, W, 4)` numeric array rather
than handing the bitmap to
[`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html):
`rasterImage` with `plot.window` uses the user-coordinate system, which
defaults (`xaxs = "r", yaxs = "r"`) to padding the interval by 4% on
each side — silently compressing the raster into ~92% of the device and
forcing sub-pixel resampling.
[`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html) uses
npc coordinates (0..1, no padding) and isn't subject to this.

(The bitmap itself is a *conformant* `nativeRaster` — its backing buffer
is row-major, so it could be handed to
[`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html)
directly; the [`as.array()`](https://rdrr.io/r/base/array.html) array
path is kept because a positional `c(H, W, 4)` array carries no
row-vs-column ambiguity for downstream consumers.)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture) && interactive()) {
  bmp <- pdf_render_page(pdf_doc_open(fixture), dpi = 96)
  plot(bmp)
}
```
