# Changelog

## pdfium (development version)

- [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md),
  [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md),
  [`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/reference/pdf_image_rendered.md)
  and
  [`pdf_text_obj_rendered_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_text_obj_rendered_bitmap.md)
  now return a **conformant** `nativeRaster`: the backing integer buffer
  is laid out row-major, so the bitmap can be passed straight to
  [`png::writePNG()`](https://rdrr.io/pkg/png/man/writePNG.html),
  [`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html) and
  R’s graphics engine with no reshape. Prior versions stored the buffer
  column-major, which sheared every row sideways when a consumer trusted
  the `nativeRaster` class (“stride streak” garble).
  [`as.array()`](https://rdrr.io/r/base/array.html) /
  [`as.raster()`](https://rdrr.io/r/grDevices/as.raster.html) are
  updated to match and remain correct. Output now matches
  [`png::readPNG()`](https://rdrr.io/pkg/png/man/readPNG.html) /
  `magick::image_read()` in dims, RGBA channel order and 0..1 range.

## pdfium 0.1.0

- Initial CRAN release.
