# Convert PDF page coordinates to device (screen) coordinates

Inverse of
[`pdf_device_to_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_device_to_page.md).
Wraps `FPDF_PageToDevice`.

## Usage

``` r
pdf_page_to_device(
  page,
  start_x,
  start_y,
  size_x,
  size_y,
  rotate,
  page_x,
  page_y
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

- page_x, page_y:

  Numeric — the point in PDF user-space (points) to convert.

## Value

Named integer vector `c(x, y)` in device pixels. `c(NA, NA)` on failure.

## See also

[`pdf_device_to_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_device_to_page.md).
