# Create a fresh in-memory bitmap

Wraps `FPDFBitmap_Create`. Allocates a `width × height` bitmap that can
be populated via
[`pdf_bitmap_fill_rect()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_fill_rect.md)
or
[`pdf_bitmap_set_buffer()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_buffer.md)
and then attached to an image page- object via
[`pdf_image_set_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_set_bitmap.md).
This is the v0.1.0 path for embedding non-JPEG (PNG / TIFF / raw raster)
images into a PDF.

## Usage

``` r
pdf_bitmap_new(width, height, alpha = TRUE)
```

## Arguments

- width, height:

  Integer — pixel dimensions. Must be positive.

- alpha:

  Logical. If `TRUE` (default), the bitmap has an alpha channel.

## Value

A `pdfium_image_buffer` handle.

## Details

Pixel layout:

- `alpha = TRUE`: BGRA, 4 bytes per pixel, top-down rows.

- `alpha = FALSE`: BGRx, 4 bytes per pixel with the 4th byte unused.

## See also

[`pdf_bitmap_close()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_close.md),
[`pdf_image_set_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_set_bitmap.md),
[`pdf_bitmap_fill_rect()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_fill_rect.md),
[`pdf_bitmap_set_buffer()`](https://humanpred.github.io/rpdfium/reference/pdf_bitmap_buffer.md).
