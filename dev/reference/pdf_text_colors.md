# Per-character fill and stroke colors and text-index mapping

Returns one row per character on the page with the fill / stroke RGBA
colour PDFium reports for that glyph and the text-position the character
occupies in the page's extracted text. Suitable for joining onto
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_chars.md)
by `char_index`.

## Usage

``` r
pdf_text_colors(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with one row per character and columns `char_index` (1-based),
`text_index` (0-based index in the page's extracted text; `NA` for
generated/hyphen/formatting chars), `fill_red`, `fill_green`,
`fill_blue`, `fill_alpha`, `stroke_red`, `stroke_green`, `stroke_blue`,
`stroke_alpha` (0-255 integers, `NA` when PDFium reports failure).

## Details

Use cases:

- Detect invisible / clip-mode text (alpha = 0 in fill *and* stroke) for
  text-extraction quality checks.

- Distinguish styled-text passages (e.g. highlights with a non-default
  fill alpha).

- Translate between the character-index space PDFium uses internally and
  the extracted-text index space that
  [`pdf_text_search()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_search.md)'s
  `start_char` aligns with — characters with `text_index = NA` are
  generated / hyphen / formatting chars that don't appear in the
  rendered text string.

Wraps `FPDFText_GetFillColor`, `FPDFText_GetStrokeColor`, and
`FPDFText_GetTextIndexFromCharIndex`.

## See also

[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_chars.md)
(per-char geometry / codepoint),
[`pdf_text_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_render_mode.md)
(per-text-object render mode).
