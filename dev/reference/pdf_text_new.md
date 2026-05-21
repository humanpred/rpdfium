# Create a new text page-object on a page

Wraps `FPDFPageObj_NewTextObj` + (optionally) `FPDFText_SetText`

- `FPDFPageObj_Transform` + `FPDFPage_InsertObject`. The text object
  uses one of the 14 PDF standard fonts (no font embedding needed);
  custom fonts are deferred to a later release.

## Usage

``` r
pdf_text_new(page, text, font = "Helvetica", font_size = 12, x = 0, y = 0)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md).
  Parent doc must be readwrite.

- text:

  Character scalar — the text content. Pass `""` to create an empty text
  object you'll populate later via
  [`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_content.md).

- font:

  Character scalar — one of the 14 PDF standard font names. Default
  `"Helvetica"`.

- font_size:

  Numeric scalar — font size in points. Default `12`.

- x, y:

  Numeric scalars — baseline position in PDF user-space points. Default
  `0, 0`.

## Value

The new `pdfium_obj` (type `"text"`), inserted on the page.

## See also

[`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_content.md),
[`pdf_text_set_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_render_mode.md),
[`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_matrix.md).
