# PDFium's default charset → TTF substitution map

Wraps `FPDF_GetDefaultTTFMapCount` + `FPDF_GetDefaultTTFMapEntry`.
Returns the static "PDF charset code → TrueType font name" substitution
table PDFium ships with the build. When a PDF references a font by
charset code only (e.g. `/Encoding /WinAnsi` with no /BaseFont
resolution), PDFium consults this table to decide which TTF to fall back
to.

## Usage

``` r
pdf_system_fonts_default_ttf_map()
```

## Value

A tibble with columns `charset` (integer code) and `fontname`
(character).

## Details

Useful for auditing why a particular missing-glyph PDF rendered with a
substitute font, and for confirming which charsets PDFium can serve
without an explicit
[`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md).

## See also

[`pdf_system_fonts_install_default()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_system_fonts_install_default.md)
to install the platform's default sys-font-info provider so the
substitution actually fires.
