# Render a PDF page to a bitmap

Rasterises one page of a PDF document via PDFium and returns a
`pdfium_bitmap` object (an integer matrix that inherits from base R's
`nativeRaster` class). Use
[`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html) for
an immediate-display path (the S3 method here routes through
[`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html) on a
3-D RGBA array, the one R-engine combination that renders
pixel-for-pixel correctly across platforms). Conversion helpers
([`as.raster.pdfium_bitmap()`](https://humanpred.github.io/rpdfium/reference/as.raster.pdfium_bitmap.md),
[`as.array.pdfium_bitmap()`](https://humanpred.github.io/rpdfium/reference/as.array.pdfium_bitmap.md),
[`as.matrix.pdfium_bitmap()`](https://humanpred.github.io/rpdfium/reference/as.matrix.pdfium_bitmap.md))
cover the other common bitmap shapes downstream packages expect.

## Usage

``` r
pdf_render_page(
  page,
  page_num = 1L,
  dpi = 72,
  background = "white",
  annotations = FALSE,
  rotation = 0L
)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

- dpi:

  Render resolution in dots per inch (default `72`, meaning one pixel
  per PDF point). Higher values give larger, sharper output at
  proportional memory cost.

- background:

  Background color drawn behind the page content before rendering.
  Accepts any string
  [`grDevices::col2rgb()`](https://rdrr.io/r/grDevices/col2rgb.html)
  understands (named color, `"#RRGGBB"`, `"#RRGGBBAA"`), or `NA` for a
  fully transparent background. Defaults to `"white"`.

- annotations:

  Logical; render annotation appearance streams on top of the page
  content. Defaults to `FALSE`.

- rotation:

  Extra rotation in degrees applied on top of the page's own `/Rotate`
  attribute. One of `0`, `90`, `180`, `270`. Note: PDFium's rotation is
  clockwise; e.g. `90` means rotate the page 90° clockwise from its
  on-page orientation.

## Value

A `pdfium_bitmap` object - an integer matrix with
`class = c("pdfium_bitmap", "nativeRaster")`, `dim = c(height, width)`,
`channels = 4L`, plus attributes `dpi`, `source_page`,
`rotation_applied`.

## See also

[`as.raster.pdfium_bitmap()`](https://humanpred.github.io/rpdfium/reference/as.raster.pdfium_bitmap.md),
[`as.array.pdfium_bitmap()`](https://humanpred.github.io/rpdfium/reference/as.array.pdfium_bitmap.md)
for output-shape conversions;
[`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)
and
[`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)
for the source page's dimensions.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  bmp <- pdf_render_page(pdf_open(fixture), dpi = 96)
  bmp # human summary
  if (interactive()) plot(bmp) # render to the active device
}
```
