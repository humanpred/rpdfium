# Font ascent and descent for a text page-object's font

Returns the font's vertical metrics — *ascent* (the maximum height above
the baseline) and *descent* (the maximum depth below the baseline,
conventionally a negative number) — at the requested `font_size`. Useful
for laying out text with consistent line heights and for converting
between PDF text coordinates (baseline-relative) and bounding-box
coordinates.

## Usage

``` r
pdf_text_font_metrics(obj, font_size = 1)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"`.

- font_size:

  Numeric font size in PDF points (default `1`, so the result is in "em"
  units — multiply by the actual font size you care about).

## Value

A named list with two numeric scalars: `ascent` and `descent`. Either is
`NA` when PDFium can't resolve it.

## Details

Wraps `FPDFFont_GetAscent` and `FPDFFont_GetDescent`.

## See also

[`pdf_text_font()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font.md)
for the font's name + weight + italic-angle metadata;
[`pdf_glyph_path()`](https://humanpred.github.io/rpdfium/reference/pdf_glyph_path.md)
for per-glyph outlines.
