# Set a page's rotation

Wraps `FPDFPage_SetRotation`. Allowed values are `0`, `90`, `180`, `270`
degrees (clockwise). The PDF spec restricts page rotation to multiples
of 90; PDFium silently treats any other value as 0.

## Usage

``` r
pdf_page_set_rotation(page, degrees, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc` (in which case `page_num` selects the page).

- degrees:

  Integer; one of `0`, `90`, `180`, `270`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

Invisibly returns the parent `pdfium_doc` so calls can be chained with
`|>`.

## Details

Polymorphic in `page`: accepts either an already-loaded `pdfium_page`
from
[`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md)
(with `readwrite = TRUE` on the parent doc) or a `pdfium_doc` plus
`page_num`.

## See also

[`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_rotation.md)
for the read side.
