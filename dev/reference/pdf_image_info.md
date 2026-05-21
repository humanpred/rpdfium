# Inspect metadata for an embedded image

Reads dimensions, DPI, bits-per-pixel, and color space from a
`pdfium_obj` of type `"image"`. Wraps `FPDFImageObj_GetImageMetadata`
(plus `FPDFImageObj_GetImagePixelSize` for the pixel dims when you only
need width/height).

## Usage

``` r
pdf_image_info(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`, typically returned by filtering
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
  on `type == "image"`.

## Value

A named list with elements `width`, `height` (integer pixels),
`horizontal_dpi`, `vertical_dpi` (numeric, may be 0 when the image has
no explicit DPI), `bits_per_pixel` (integer), `colorspace` (character;
one of "Unknown", "DeviceGray", "DeviceRGB", "DeviceCMYK", "CalGray",
"CalRGB", "Lab", "ICCBased", "Separation", "DeviceN", "Indexed",
"Pattern"), and `marked_content_id` (integer; `-1` when absent).

## See also

[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_bitmap.md)
for the decoded pixels,
[`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_rendered.md)
for the page-CTM-applied rendering,
[`pdf_image_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_data.md)
for the raw stream bytes.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "image.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  page <- pdf_page_load(doc, 1L)
  imgs <- Filter(function(o) o$type == "image", pdf_page_objects(page))
  if (length(imgs) > 0L) pdf_image_info(imgs[[1L]])
  pdf_page_close(page)
  pdf_doc_close(doc)
}
```
