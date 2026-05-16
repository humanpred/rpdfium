# Pixel size of an embedded image

Faster alternative to
[`pdf_image_info()`](https://humanpred.github.io/rpdfium/reference/pdf_image_info.md)
when only the source-pixel dimensions are needed. Wraps
`FPDFImageObj_GetImagePixelSize`.

## Usage

``` r
pdf_image_size(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`.

## Value

An integer vector with named elements `width` and `height`.

## See also

[`pdf_image_info()`](https://humanpred.github.io/rpdfium/reference/pdf_image_info.md)
for the full metadata block.
