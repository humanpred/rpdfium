# Auto-detected web links in a page's text

Returns one row per URL that PDFium's web-link detector finds in the
page's extracted text. Detected patterns include `http://...`,
`https://...`, `www.example.com`, and `mailto:user@host`. Wraps
`FPDFLink_LoadWebLinks` plus `FPDFLink_GetURL`, `FPDFLink_GetTextRange`,
`FPDFLink_CountRects`, and `FPDFLink_GetRect`.

## Usage

``` r
pdf_text_weblinks(page, page_num = 1L)
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

A tibble with one row per detected URL and columns:

- `url` (character) — the matched URL string. UTF-8.

- `start_char` (integer) — 0-based character offset of the URL on the
  page's text page.

- `char_count` (integer) — number of characters in the matched span.

- `left`, `bottom`, `right`, `top` (numeric) — axis-aligned union of the
  URL's per-line rectangles in PDF user-space points. `NA` when PDFium
  reports no bounds.

Returns a 0-row tibble of the same schema when no URLs are detected.

## Details

This is distinct from
[`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md),
which enumerates the clickable link *annotations* declared by the PDF
author. Use `pdf_text_weblinks()` when the URL appears as plain text on
the page (no link annotation), and
[`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md)
when you want the explicit clickable regions.

Multi-line URLs produce one row whose bounding box is the axis-aligned
union of every contributing line's rectangle. If you need a rectangle
per line, pair `start_char` and `char_count` with
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
over `start_char:(start_char + char_count - 1L)`.

## See also

[`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md)
for link annotations,
[`pdf_text_search()`](https://humanpred.github.io/rpdfium/reference/pdf_text_search.md)
for arbitrary string search.
