# Transform every annotation on a page in one shot

Wraps `FPDFPage_TransformAnnots`. Applies the 6-tuple matrix
`(a, b, c, d, e, f)` to all annotations on `page` simultaneously — the
same matrix shape used by
[`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_matrix.md)
for page objects.

## Usage

``` r
pdf_page_transform_annots(page, matrix, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` or `pdfium_doc`.

- matrix:

  Numeric length-6 vector `c(a, b, c, d, e, f)`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Polymorphic in `page`: accepts either a `pdfium_page` (with parent doc
readwrite) or a `pdfium_doc` plus `page_num`.
