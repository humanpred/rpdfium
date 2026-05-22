# Extract text inside a bounding rectangle

Wraps `FPDFText_GetBoundedText`. Returns the Unicode characters on
`page` whose glyph centers fall inside the rectangle defined by
`(left, bottom, right, top)` in PDF user-space points.

## Usage

``` r
pdf_text_bounded(page, bounds)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md).

- bounds:

  Numeric length-4 vector `c(left, bottom, right, top)`.

## Value

Character scalar. Empty string `""` when no characters fall inside the
rectangle.

## Details

Pairs naturally with
[`pdf_text_rects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_rects.md)
(which produces the rectangles in the first place) and with downstream
geometry-driven extraction workflows.

## See also

[`pdf_text_rects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_rects.md),
[`pdf_doc_text()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_text.md).
