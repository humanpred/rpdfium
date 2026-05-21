# Create a new text page-object on a page

Wraps `FPDFPageObj_NewTextObj` (when `font` is a standard-font name) or
`FPDFPageObj_CreateTextObj` (when `font` is a custom `pdfium_font`
handle from
[`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_standard.md)
/
[`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md)).
Either path is followed by an optional `FPDFText_SetText`,
`FPDFPageObj_Transform`, and `FPDFPage_InsertObject`.

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

  Either a character scalar — one of the 14 PDF standard font names (see
  [`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_standard.md)
  for the list) — or a `pdfium_font` handle from
  [`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_standard.md)
  or
  [`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md).
  Default `"Helvetica"`. Pass a `pdfium_font` handle when you need a
  custom TrueType / Type1 font; the standard-font shortcut is purely for
  convenience.

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
[`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_matrix.md),
[`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_standard.md),
[`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md).
