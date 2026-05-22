# Extract the bytes of an embedded font

Wraps `FPDFFont_GetFontData`. Useful for round-tripping an embedded font
from one PDF to another, piping into `systemfonts` / `fontmgr`-style
introspection, or auditing what's actually been embedded.

## Usage

``` r
pdf_font_data(font)
```

## Arguments

- font:

  A `pdfium_font` from
  [`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md),
  [`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_standard.md),
  or
  [`pdf_text_font()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_font.md)
  (the reader side, which returns the per-text-object font).

## Value

Raw vector of font bytes. `raw(0)` if PDFium reports the font has no
embedded data (e.g. a referenced-only standard font).
