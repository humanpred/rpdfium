# Convert a pdfium_bitmap to base R's `"raster"` (character hex)

Returns a character matrix of `"#RRGGBBAA"` strings - the shape base R's
`"raster"` class uses (and that
[`grDevices::as.raster.matrix()`](https://rdrr.io/r/grDevices/as.raster.html)
would produce on a hex-character input). Note that R's nativeRaster
integer encoding has no direct
[`as.raster()`](https://rdrr.io/r/grDevices/as.raster.html) method; this
converter does the byte-unpacking explicitly.

## Usage

``` r
# S3 method for class 'pdfium_bitmap'
as.raster(x, ...)
```

## Arguments

- x:

  A `pdfium_bitmap` from
  [`pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md).

- ...:

  Ignored.

## Value

A `"raster"` object (character matrix of hex colors).
