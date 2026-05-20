# Set one of a page's named bounding boxes

Wraps `FPDFPage_Set{Media,Crop,Bleed,Trim,Art}Box`. Companion to
[`pdf_page_box()`](https://humanpred.github.io/rpdfium/reference/pdf_page_box.md).

## Usage

``` r
pdf_page_set_box(page, box, rect, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc` (in which case `page_num` selects the page).

- box:

  One of `"media"`, `"crop"`, `"bleed"`, `"trim"`, `"art"`.

- rect:

  Length-4 numeric `c(left, bottom, right, top)` in PDF user-space
  points.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Polymorphic in `page`.

## See also

[`pdf_page_box()`](https://humanpred.github.io/rpdfium/reference/pdf_page_box.md)
for the read side.
