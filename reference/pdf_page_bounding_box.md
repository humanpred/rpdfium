# Page bounding box (cropbox ∩ mediabox)

Wraps `FPDF_GetPageBoundingBox` — returns the rectangle that encloses
the visible portion of `page` after intersecting the cropbox with the
mediabox. Often the same as the cropbox; differs when a cropbox sticks
out beyond the mediabox.

## Usage

``` r
pdf_page_bounding_box(page)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md).

## Value

Named numeric vector of length 4 — `c(left, bottom, right, top)` in PDF
user-space points. All-`NA` on failure.

## Details

For named boxes (media / crop / bleed / trim / art), use
[`pdf_page_box()`](https://humanpred.github.io/rpdfium/reference/pdf_page_box.md).

## See also

[`pdf_page_box()`](https://humanpred.github.io/rpdfium/reference/pdf_page_box.md)
for individual named boxes.
