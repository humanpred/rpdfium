# Convert device (screen) coordinates to PDF page coordinates

Wraps `FPDF_DeviceToPage`. Given a rendering window of size
`(size_x, size_y)` pixels at top-left `(start_x, start_y)` with rotation
`rotate`, maps the device pixel `(device_x, device_y)` to a point in PDF
user-space (points).

## Usage

``` r
pdf_device_to_page(
  page,
  start_x,
  start_y,
  size_x,
  size_y,
  rotate,
  device_x,
  device_y
)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md).

- start_x, start_y:

  Integer — device-pixel position of the display area's top-left.

- size_x, size_y:

  Integer — pixel size of the rendering window.

- rotate:

  Integer — `0`, `1`, `2`, or `3` (clockwise quarter turns). Same
  convention as PDFium's other rendering functions.

- device_x, device_y:

  Integer — the pixel to convert.

## Value

Named numeric vector `c(x, y)` in PDF points. `c(NA, NA)` on failure.

## Details

Useful when a downstream consumer reports a click position in pixels
(e.g. from a Shiny `clickOpts` event) and you want to translate it back
to PDF coordinates for hit-testing against page objects.

## See also

[`pdf_page_to_device()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_to_device.md)
for the inverse.
