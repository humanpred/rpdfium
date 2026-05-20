# Reverse-map a character index to its page-object index

Given a 1-based `char_index` on the page's text page (matching the
`char_index` column of
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)),
return the 1-based page-object index of the text run that contains it.
Wraps `FPDFText_GetTextObject` plus a lookup into the page's object
table.

## Usage

``` r
pdf_text_char_obj_index(page, char_index, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- char_index:

  One-based character index (matches `pdf_text_chars()$char_index`).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

Integer scalar — the 1-based page-object index, or `NA` when the
character has no associated page object (e.g. PDFium-synthesised
whitespace).

## Details

Useful for jumping from a per-character readout back to the parent text
page object's style / position metadata in
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
(which uses the same `obj_index`).

## See also

[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md),
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md).
