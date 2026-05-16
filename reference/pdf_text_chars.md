# Per-character text extraction

Returns one tibble row per character on the page, with the character's
Unicode codepoint and UTF-8 form, glyph bounding box, effective font
size, and two PDF flags indicating "generated" characters (whitespace
PDFium inferred between positioned glyphs) and end-of-line "soft"
hyphens. Wraps `FPDFText_LoadPage` plus `FPDFText_CountChars` /
`_GetUnicode` / `_GetCharBox` / `_GetFontSize` / `_IsGenerated` /
`_IsHyphen`.

## Usage

``` r
pdf_text_chars(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with columns:

- `char_index` integer - 1-based position in the page's character
  stream.

- `codepoint` integer - Unicode code point.

- `char` character - UTF-8 character; empty for surrogate halves or
  PDFium's NUL sentinel.

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` - glyph
  bounding box in PDF user space.

- `font_size` numeric - effective glyph height in user-space points (the
  run's font size times the text matrix scale).

- `is_generated` logical - `TRUE` for whitespace PDFium synthesised
  between positioned glyphs (the source PDF does not carry a character
  there; PDFium infers one for text-extraction consumers).

- `is_hyphen` logical - `TRUE` for end-of-line soft hyphens.

Returns a 0-row tibble of the same schema when the page has no text.

## Details

This is the per-character analog of
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
(per-text-object) and
[`pdf_text()`](https://humanpred.github.io/rpdfium/reference/pdf_text.md)
(per-page). The three coexist: use
[`pdf_text()`](https://humanpred.github.io/rpdfium/reference/pdf_text.md)
when you just want the strings,
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
for object-level positions, and `pdf_text_chars()` when you need
glyph-level geometry (e.g. word segmentation, character-by-character
layout analysis).

## See also

[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md),
[`pdf_text()`](https://humanpred.github.io/rpdfium/reference/pdf_text.md).
