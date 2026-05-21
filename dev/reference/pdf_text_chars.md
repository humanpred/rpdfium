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
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
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

- `origin_x`, `origin_y` - the character's glyph origin point in PDF
  user space (`FPDFText_GetCharOrigin`). Distinct from the bounding-box
  corners; for many fonts the origin is at the baseline left of the
  glyph.

- `loose_left`, `loose_bottom`, `loose_right`, `loose_top` - the "loose"
  bounding box covering the entire glyph cell (font ascent / descent
  included), not just the glyph outline. Use these when you need
  consistent line heights; use `bounds_*` for the tight glyph extent.

- `unicode_map_error` logical - `TRUE` when PDFium detected that the
  character's ToUnicode CMap is malformed for this glyph (the codepoint
  reported may be the PDF's \` fallback rather than the intended
  character).

- `text_index` integer - 0-based position in the *extractable* text
  string (i.e. the linear
  [`pdf_doc_text()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_text.md)
  output) for this character, or `NA` for synthesised whitespace and
  other characters that don't appear in the extracted text.

- `char_font_name` character - the font name PDFium reports for this
  specific character (via `FPDFText_GetFontInfo`). Per-character because
  pages can mix fonts within a single text run after PDFium re-flows
  characters during extraction.

- `char_font_flags` integer - the PDF Font Descriptor `/Flags` bitmask
  for this character's font (PDF spec Table 121). Useful for detecting
  `/Symbolic` (bit 3) or `/AllCap` (bit 17) fonts whose ToUnicode
  mapping may be unreliable.

Returns a 0-row tibble of the same schema when the page has no text.

## Details

This is the per-character analog of
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_runs.md)
(per-text-object) and
[`pdf_doc_text()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_text.md)
(per-page). The three coexist: use
[`pdf_doc_text()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_text.md)
when you just want the strings,
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_runs.md)
for object-level positions, and `pdf_text_chars()` when you need
glyph-level geometry (e.g. word segmentation, character-by-character
layout analysis).

## See also

[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_runs.md),
[`pdf_doc_text()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_text.md).
