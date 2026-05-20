# Rendered bitmap of a single text page-object

Returns a `pdfium_bitmap` of the rendered glyphs in `obj`, scaled by
`scale` (1.0 = 1 PDF point per pixel). Useful for previewing a single
text run without rendering the full page. Wraps
`FPDFTextObj_GetRenderedBitmap`.

## Usage

``` r
pdf_text_obj_rendered_bitmap(obj, scale = 1)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md).

- scale:

  Numeric scale factor (default `1`). Larger values produce
  higher-resolution bitmaps.

## Value

A `pdfium_bitmap` integer matrix (nativeRaster ABGR encoding) or `NULL`
when PDFium reports failure.

## See also

[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)
for whole-page rendering;
[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
for image objects.
