# Rectangles occupied by a character range

Wraps `FPDFText_CountRects` + `FPDFText_GetRect`. Returns the
rectangular regions occupied by the characters in
`[start_char, start_char + char_count)` on `page`. Multi-line text
produces one rectangle per line; rotated or skewed text produces tighter
axis-aligned rectangles per glyph cluster.

## Usage

``` r
pdf_text_rects(page, start_char = 1L, char_count = -1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md).

- start_char:

  One-based character index (matches `pdf_text_chars()$char_index`).

- char_count:

  Number of characters to cover. Use `-1L` to include everything from
  `start_char` to the end of the page.

## Value

A tibble with columns `left`, `top`, `right`, `bottom` in PDF user-space
points. May have 0 rows if PDFium reports no visible rectangles.

## See also

[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
for per-character geometry.
