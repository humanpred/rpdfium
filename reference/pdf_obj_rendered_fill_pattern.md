# Rendered tile of a page object's fill or stroke pattern

When a page object is painted with a *tiling pattern* (a color from a
`/Pattern` color space whose pattern has `/PatternType 1`: hatching,
dots, checkerboards, repeated logos), these return one tile of the
pattern rendered to a bitmap. Wraps `FPDFPageObj_GetRenderedFillPattern`
and `FPDFPageObj_GetRenderedStrokePattern`.

## Usage

``` r
pdf_obj_rendered_fill_pattern(obj)

pdf_obj_rendered_stroke_pattern(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
  (typically a path or text object).

## Value

A `pdfium_bitmap` (see
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md))
holding one pattern tile, or `NULL` when the fill (stroke) color is not
a tiling pattern, e.g. a plain color or a shading pattern.

## Details

The tile is rasterized in pattern space at one pixel per unit of the
pattern's `/BBox`. Neither the pattern's `/Matrix` nor the page's
transformation is applied, so the bitmap shows the cell as authored
rather than at its on-page scale or rotation. PDFium returns the tile
bottom-up; its rows are flipped so that, like every other
`pdfium_bitmap`, the first row is the top of the tile.

The stroke variant reports the pattern held in the object's stroke color
whether or not the object is actually stroked; see
[`pdf_path_draw_mode()`](https://humanpred.github.io/rpdfium/reference/pdf_path_draw_mode.md).

## See also

[`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md)
and
[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_stroke.md)
for plain colors.
