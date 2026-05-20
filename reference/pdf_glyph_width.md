# Width of a glyph in a text page-object's font

Returns the advance width of the glyph in PDF user-space points at the
requested `font_size`. Useful for measuring glyph layout independent of
the bounding-box reported by
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md),
or for spot-checking that a font's reported width matches what it draws.

## Usage

``` r
pdf_glyph_width(obj, glyph_code, font_size = NA_real_)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"`.

- glyph_code:

  Single non-negative integer; see the section above.

- font_size:

  Numeric font size in PDF points. When `NA` (default), uses the text
  object's own font size — the most common choice when matching what is
  drawn on the page.

## Value

Numeric scalar, the glyph's width in PDF points. `NA` when PDFium
reports failure (typically a font / glyph_code mismatch).

## Details

Wraps `FPDFTextObj_GetFont` -\> `FPDFFont_GetGlyphWidth`.

## See also

[`pdf_glyph_path()`](https://humanpred.github.io/rpdfium/reference/pdf_glyph_path.md),
[`pdf_text_font_metrics()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_metrics.md).
