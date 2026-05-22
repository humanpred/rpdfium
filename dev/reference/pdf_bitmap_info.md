# Bitmap dimensions and format

Wraps `FPDFBitmap_GetWidth`, `_GetHeight`, `_GetStride`, and
`_GetFormat`. Returns a list with the bitmap's pixel layout (width ×
height) plus stride in bytes and the PDFium format code.

## Usage

``` r
pdf_bitmap_info(bitmap)
```

## Arguments

- bitmap:

  A `pdfium_image_buffer`.

## Value

Named list — `width`, `height`, `stride`, `format`.

## Details

Format codes (from `fpdfview.h`'s `FPDFBitmap_*` macros):

- `1` = Gray (1 byte/pixel)

- `2` = BGR (3 bytes/pixel)

- `3` = BGRx (4 bytes/pixel, 4th byte unused)

- `4` = BGRA (4 bytes/pixel with alpha)
