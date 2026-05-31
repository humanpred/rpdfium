# Release a bitmap handle

Wraps `FPDFBitmap_Destroy`. Idempotent. After
[`pdf_image_set_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_set_bitmap.md)
has attached the bitmap to a page-object, explicit close is safe (PDFium
has copied the pixel data into the PDF — closing only releases the
standalone in-memory bitmap, not the embedded image).

## Usage

``` r
pdf_bitmap_close(bitmap)
```

## Arguments

- bitmap:

  A `pdfium_image_buffer`.

## Value

Invisibly returns `bitmap`.
