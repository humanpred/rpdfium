# Set a bitmap on an image page-object

Wraps `FPDFImageObj_SetBitmap`. PDFium copies the bitmap's pixel data
into the document immediately; closing the `bitmap` handle afterward is
safe (and recommended for deterministic release).

## Usage

``` r
pdf_image_set_bitmap(image, bitmap)
```

## Arguments

- image:

  A `pdfium_obj` of `type = "image"`.

- bitmap:

  A `pdfium_image_buffer`.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Typical workflow:

    bm <- pdf_bitmap_new(width = 100, height = 100)
    pdf_bitmap_set_buffer(bm, my_bgra_bytes)
    img <- pdf_image_new(page, jpeg = raw(0), bounds = c(0, 0, 200, 200))
    pdf_image_set_bitmap(img, bm)
    pdf_bitmap_close(bm)

## See also

[`pdf_image_new()`](https://humanpred.github.io/rpdfium/reference/pdf_image_new.md)
for the JPEG-only path that doesn't require a bitmap.
