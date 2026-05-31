# Find an annotation's page-relative index by handle

Wraps `FPDFPage_GetAnnotIndex`. Useful after
[`pdf_annot_new()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_new.md)
when you want to know the position of the freshly-created annotation
inside the page's annot list (e.g. to coordinate with index-driven code
paths).

## Usage

``` r
pdf_annot_index(annot)
```

## Arguments

- annot:

  A `pdfium_annot` from
  [`pdf_annot_new()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_new.md)
  or
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).

## Value

Integer scalar — one-based annotation index on the parent page, or
`NA_integer_` if the annotation is not found.

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).
