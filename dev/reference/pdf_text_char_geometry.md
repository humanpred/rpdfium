# Per-character geometry: transformation matrix, rotation angle, font weight

Wraps `FPDFText_GetMatrix`, `FPDFText_GetCharAngle`, and
`FPDFText_GetFontWeight`. Returns a tibble with one row per character on
`page` (matching the row count of
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_chars.md)).

## Usage

``` r
pdf_text_char_geometry(page)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md).

## Value

A tibble with columns `char_index`, `matrix`, `angle_deg`,
`font_weight`. The matrix column is *stored as a list-column of length-6
numeric vectors* so the tibble round-trips through `dplyr` cleanly.

## Details

The `matrix` column is a 6-column numeric matrix where row `i` holds the
`(a, b, c, d, e, f)` 2D affine matrix for character `i` (1-indexed).
`angle_deg` is the rotation in degrees; `font_weight` is PDFium's
CSS-style weight integer (e.g. 400 = regular, 700 = bold), `NA_integer_`
if PDFium can't determine it.

## See also

[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_chars.md)
for the broader per-character tibble.
