# Raw bytes of an embedded image stream

Returns the bytes that back the image object - either the uncompressed
pixel buffer (`decoded = TRUE`) or the raw embedded stream as it sits in
the PDF (`decoded = FALSE`). The raw form is useful when you want to
write the original JPEG / JBIG2 / JPEG2000 / Flate-deflated bitmap to
disk without re-encoding; pair it with
[`pdf_image_filters()`](https://humanpred.github.io/rpdfium/reference/pdf_image_filters.md)
to know which decoders the PDF specifies.

## Usage

``` r
pdf_image_data(obj, decoded = TRUE)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`.

- decoded:

  Logical scalar. `TRUE` (default) returns the decompressed pixel data
  after applying all filters; `FALSE` returns the stream bytes as
  stored.

## Value

A raw vector. Length is whatever PDFium reports - the filter-applied
size for `decoded = TRUE`, the stored byte count for `decoded = FALSE`.

## Details

Wraps `FPDFImageObj_GetImageDataDecoded` or
`FPDFImageObj_GetImageDataRaw` (chosen by `decoded`).

## See also

[`pdf_image_filters()`](https://humanpred.github.io/rpdfium/reference/pdf_image_filters.md),
[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md).
