# Set the render mode of a text page object

Wraps `FPDFTextObj_SetTextRenderMode`. Allowed values mirror
[`pdf_text_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_render_mode.md)'s
names: `"fill"`, `"stroke"`, `"fill_stroke"`, `"invisible"`,
`"fill_clip"`, `"stroke_clip"`, `"fill_stroke_clip"`, `"clip"`.

## Usage

``` r
pdf_text_set_render_mode(obj, mode)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"`. Parent doc must be readwrite.

- mode:

  Character scalar; one of the eight render-mode names listed above.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_text_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_render_mode.md).
