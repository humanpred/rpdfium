# Convert a pdfium_bitmap to a hex-color matrix

Alias for `as.raster(x)`, included for symmetry with R's other raster
classes.

## Usage

``` r
# S3 method for class 'pdfium_bitmap'
as.matrix(x, ...)
```

## Arguments

- x:

  A `pdfium_bitmap` from
  [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md).

- ...:

  Ignored.

## Value

A character matrix of `"#RRGGBBAA"` colors.
