# Locate the character index nearest a (x, y) point on a page

Returns the 1-based index of the character whose bounding box contains
(or is closest within `tolerance`) the given point. Wraps
`FPDFText_GetCharIndexAtPos`.

## Usage

``` r
pdf_text_char_at_point(page, x, y, tolerance = 2, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- x, y:

  Point in PDF user-space points.

- tolerance:

  Numeric of length 1 or 2; absolute slack (in PDF points) PDFium is
  allowed to use when no character directly contains `(x, y)`. Length-2
  sets `x` and `y` tolerance independently. Default `2`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

Integer scalar — the 1-based character index, or `NA` when no character
is within tolerance.

## See also

[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_chars.md).
