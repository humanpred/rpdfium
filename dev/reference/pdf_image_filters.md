# Filter chain for an embedded image stream

Returns the names of the filters PDFium applies, in order, to decode the
embedded image. Common values include `"DCTDecode"` (JPEG),
`"FlateDecode"` (Deflate), `"JBIG2Decode"`, `"JPXDecode"` (JPEG 2000),
`"CCITTFaxDecode"`, and `"ASCII85Decode"`. Wraps
`FPDFImageObj_GetImageFilterCount` plus repeated
`FPDFImageObj_GetImageFilter` calls.

## Usage

``` r
pdf_image_filters(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`.

## Value

A character vector. Empty when the image stream has no filters declared
(e.g. uncompressed inline images).

## See also

[`pdf_image_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_data.md).
