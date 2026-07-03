# pdfium (development version)

* `pdf_render_page()`, `pdf_image_bitmap()`, `pdf_image_rendered()` and
  `pdf_text_obj_rendered_bitmap()` now return a **conformant**
  `nativeRaster`: the backing integer buffer is laid out row-major, so
  the bitmap can be passed straight to `png::writePNG()`,
  `grid::grid.raster()` and R's graphics engine with no reshape. Prior
  versions stored the buffer column-major, which sheared every row
  sideways when a consumer trusted the `nativeRaster` class ("stride
  streak" garble). `as.array()` / `as.raster()` are updated to match
  and remain correct. Output now matches `png::readPNG()` /
  `magick::image_read()` in dims, RGBA channel order and 0..1 range.

# pdfium 0.1.0

* Initial CRAN release.
