# Fill a rectangle of the bitmap with a solid color

Wraps `FPDFBitmap_FillRect`. Coordinate origin is the top-left pixel (0,
0). Color is encoded as the integer `0xAARRGGBB`.

## Usage

``` r
pdf_bitmap_fill_rect(bitmap, left, top, width, height, color)
```

## Arguments

- bitmap:

  A `pdfium_image_buffer`.

- left, top, width, height:

  Integer — rectangle in bitmap pixels.

- color:

  Integer — color as `0xAARRGGBB`. Use `bitmap_color(r, g, b, a)` for a
  friendly constructor.

## Value

Invisibly returns `bitmap`.
