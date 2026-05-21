# Text-rendering mode of a text page-object

Returns the PDF text-rendering mode (the `Tr` operand) for a text
object. The mode determines whether the glyphs are filled, stroked,
both, invisible (so the text contributes only to text selection /
search), or used as a clipping path. Wraps
`FPDFTextObj_GetTextRenderMode`.

## Usage

``` r
pdf_text_render_mode(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

## Value

Character scalar; one of `"fill"` (the default), `"stroke"`,
`"fill_stroke"`, `"invisible"`, `"fill_clip"`, `"stroke_clip"`,
`"fill_stroke_clip"`, `"clip"`, or `"unknown"` (PDFium couldn't
determine).
