# Load one of the 14 PDF standard fonts

Wraps `FPDFText_LoadStandardFont`. The 14 standard fonts (Helvetica /
Times-Roman / Courier in their four weight+style variants, plus Symbol
and ZapfDingbats) are required by the PDF spec to be supported by every
reader, so no font bytes need to be embedded.

## Usage

``` r
pdf_font_load_standard(doc, name)
```

## Arguments

- doc:

  A `pdfium_doc` opened with `readwrite = TRUE`.

- name:

  Character scalar — one of the 14 standard font names listed in the
  **Standard fonts** section below.

## Value

A `pdfium_font` handle. Pass it as the `font` argument of
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md).

## Details

For arbitrary TrueType / Type1 fonts, use
[`pdf_font_load()`](https://humanpred.github.io/rpdfium/reference/pdf_font_load.md).

## Standard fonts

`"Helvetica"`, `"Helvetica-Bold"`, `"Helvetica-Oblique"`,
`"Helvetica-BoldOblique"`, `"Times-Roman"`, `"Times-Bold"`,
`"Times-Italic"`, `"Times-BoldItalic"`, `"Courier"`, `"Courier-Bold"`,
`"Courier-Oblique"`, `"Courier-BoldOblique"`, `"Symbol"`,
`"ZapfDingbats"`.

## See also

[`pdf_font_load()`](https://humanpred.github.io/rpdfium/reference/pdf_font_load.md),
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md),
[`pdf_font_close()`](https://humanpred.github.io/rpdfium/reference/pdf_font_close.md).

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- pdf_doc_new()
page <- pdf_page_new(doc, width = 612, height = 792)
font <- pdf_font_load_standard(doc, "Times-Italic")
pdf_text_new(page, "hello", font = font, font_size = 24,
             x = 72, y = 720)
pdf_save(doc, tempfile(fileext = ".pdf"))
} # }
```
