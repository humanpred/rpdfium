# Convert a pdfium_bitmap to a 3D RGBA array of doubles in 0..1

Matches the format that
[`png::writePNG()`](https://rdrr.io/pkg/png/man/writePNG.html) and
`pdftools::pdf_render_page()` both produce: a numeric array with
dimensions `c(height, width, 4)` and values in the closed interval 0 to
1.

## Usage

``` r
# S3 method for class 'pdfium_bitmap'
as.array(x, ...)
```

## Arguments

- x:

  A `pdfium_bitmap` from
  [`pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md).

- ...:

  Ignored.

## Value

A numeric array, dim `c(height, width, 4)`, channels ordered red, green,
blue, alpha.
