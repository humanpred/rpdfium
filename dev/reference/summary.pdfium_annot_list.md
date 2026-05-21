# Tibble-shaped summary of an annotation list

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_annot_list`. Defers to
[`as_tibble.pdfium_annot_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_annot_list.md)
for the standard tibble view.

## Usage

``` r
# S3 method for class 'pdfium_annot_list'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_annot_list` from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md).

- ...:

  Forwarded to
  [`as_tibble.pdfium_annot_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_annot_list.md).

## Value

The tibble returned by
[`as_tibble.pdfium_annot_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_annot_list.md).
