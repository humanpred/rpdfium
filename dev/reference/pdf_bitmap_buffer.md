# Read or write the bitmap's raw pixel bytes

`pdf_bitmap_buffer()` returns a raw vector of length `stride * height`
containing the bitmap's pixel data exactly as PDFium stores it.
`pdf_bitmap_set_buffer()` writes a raw vector of the same length into
the bitmap (length is checked).

## Usage

``` r
pdf_bitmap_buffer(bitmap)

pdf_bitmap_set_buffer(bitmap, bytes)
```

## Arguments

- bitmap:

  A `pdfium_image_buffer`.

- bytes:

  For `pdf_bitmap_set_buffer()` — a raw vector of length
  `stride * height`.

## Value

`pdf_bitmap_buffer()` returns a raw vector; `pdf_bitmap_set_buffer()`
returns `bitmap` invisibly.

## Details

The byte order depends on the format reported by
[`pdf_bitmap_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bitmap_info.md).
For BGRA the i'th pixel at row `r`, col `c` is
`buf[stride * r + 4 * c + 1:4] == c(B, G, R, A)`.
