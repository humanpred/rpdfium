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

We go through `as.array(x)` rather than handing the integer matrix
directly to
[`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html)
for two reasons that compound:

1.  Per the documented raster contract (see
    [`?grDevices::as.raster`](https://rdrr.io/r/grDevices/as.raster.html),
    "Raster images are internally represented row-first"), `"raster"`
    and `nativeRaster` objects must have row-major memory layout. R's
    `as.raster.matrix()` transposes its input precisely to satisfy that.
    Our integer matrix comes out of C++ as a standard R column-major
    matrix, so feeding it directly is non-conformant and shows diagonal
    stripe artifacts on detailed content.

2.  `rasterImage` with `plot.window` uses the user-coordinate system,
    which defaults (`xaxs = "r", yaxs = "r"`) to padding the interval by
    4% on each side — silently compressing the raster into ~92% of the
    device and forcing sub-pixel resampling.
    [`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html)
    uses npc coordinates and isn't subject to this.

Going through `as.array(x)` to a 3-D `c(H, W, 4)` numeric array and
rendering with
[`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html)
sidesteps both: the array path uses positional channel storage (no
row-vs-column convention), and grid coordinates are 0..1 npc without
padding.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture) && interactive()) {
  bmp <- pdf_render_page(pdf_open(fixture), dpi = 96)
  plot(bmp)
}
```
