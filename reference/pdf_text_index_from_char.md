# Map between PDFium's "all characters" and "extractable text" indices

PDFium's text page surfaces two parallel views of the page's text: the
full *character* list (positioned glyphs including PDFium-synthesised
whitespace between them), and the *extractable text* string (only
characters that appear in
[`pdf_text()`](https://humanpred.github.io/rpdfium/reference/pdf_text.md)'s
output). These helpers translate between the two indexing systems.

## Usage

``` r
pdf_text_index_from_char(page, char_index, page_num = 1L)

pdf_text_char_from_text_index(page, text_index, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc`.

- char_index:

  One-based character index (matches `pdf_text_chars()$char_index`).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

- text_index:

  Zero-based offset into the extractable text string.

## Value

An integer scalar — the converted index, or `NA` when the character has
no counterpart in the other indexing system.

## Details

`pdf_text_index_from_char()` converts a 1-based `char_index` (matches
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)'s
`char_index` column) into the 0-based position in the extractable text
string, or `NA` if the character has no extractable-text counterpart.

`pdf_text_char_from_text_index()` does the reverse: given a 0-based
text-string index, returns the 1-based `char_index`.

Wraps `FPDFText_GetTextIndexFromCharIndex` /
`FPDFText_GetCharIndexFromTextIndex`.

## See also

[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md),
[`pdf_text()`](https://humanpred.github.io/rpdfium/reference/pdf_text.md),
[`pdf_text_search()`](https://humanpred.github.io/rpdfium/reference/pdf_text_search.md).
