# Decoded ICC color profile bytes for an embedded image

Returns the raw bytes of the ICC color profile attached to the image's
colour space, if any. Useful for callers that need to reproduce the
colour rendering exactly (e.g. when re-encoding the image outside
PDFium). Wraps `FPDFImageObj_GetIccProfileDataDecoded`.

## Usage

``` r
pdf_image_icc_profile(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`.

## Value

A `raw` vector. Length zero when the image has no ICC profile.

## Details

Most embedded images carry no ICC profile — they use a standard colour
space (`/DeviceRGB`, `/DeviceGray`, etc.). This function returns
`raw(0)` in that common case.
