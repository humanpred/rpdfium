# Render a PDF page with an arbitrary affine transformation

Power-user counterpart to
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md).
Instead of choosing a DPI + rotation, the caller supplies a 3x2 affine
transformation matrix and the destination bitmap's pixel dimensions,
plus an optional clipping rectangle in PDF user-space points. Useful
for:

## Usage

``` r
pdf_render_page_with_matrix(
  page,
  matrix,
  pixel_width,
  pixel_height,
  clip_rect = NULL,
  page_num = 1L,
  background = "white",
  annotations = FALSE
)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- matrix:

  Length-6 numeric vector (or 3x2 / 2x3 matrix coerced to length-6).

- pixel_width, pixel_height:

  Output bitmap dimensions in pixels (positive integers).

- clip_rect:

  Length-4 numeric `c(left, bottom, right, top)` in PDF user-space
  points, or `NULL` to skip clipping.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

- background:

  Background color drawn behind the page content before rendering.
  Accepts any string
  [`grDevices::col2rgb()`](https://rdrr.io/r/grDevices/col2rgb.html)
  understands (named color, `"#RRGGBB"`, `"#RRGGBBAA"`), or `NA` for a
  fully transparent background. Defaults to `"white"`.

- annotations:

  Logical; render annotation appearance streams on top of the page
  content. Defaults to `FALSE`.

## Value

A `pdfium_bitmap`.

## Details

- Rendering a cropped region of a page (set the matrix to scale

  - translate the desired region into the bitmap, plus a matching
    `clip_rect` to discard everything outside).

- Implementing zoom / pan in interactive viewers.

- Pre-warping for non-rectilinear projections (the matrix can include
  shear).

Wraps `FPDF_RenderPageBitmapWithMatrix`.

## Matrix layout

`matrix` is a 3x2 numeric matrix (or a length-6 numeric vector)
representing the PDFium-order affine transformation
`(a, b, c, d, e, f)`, applied as:

\$\$x' = a\cdot x + c\cdot y + e\$\$ \$\$y' = b\cdot x + d\cdot y +
f\$\$

For a simple scale, use
`matrix(c(s, 0, 0, s, 0, 0), 3, 2, byrow = TRUE)`. To crop to `(x0, y0)`
-\> `(x1, y1)` at scale `s`, use
`matrix(c(s, 0, 0, s, -s*x0, -s*y0), 3, 2, byrow = TRUE)` plus
`clip_rect = c(x0, y0, x1, y1)`.

## See also

[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)
for the simpler dpi+rotation API.
