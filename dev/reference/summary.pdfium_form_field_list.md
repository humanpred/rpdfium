# Tibble-shaped summary of a form-field list

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_form_field_list`. Defers to
[`as_tibble.pdfium_form_field_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_form_field_list.md)
for the standard tibble view.

## Usage

``` r
# S3 method for class 'pdfium_form_field_list'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_form_field_list` from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

- ...:

  Forwarded to
  [`as_tibble.pdfium_form_field_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_form_field_list.md).

## Value

The tibble returned by
[`as_tibble.pdfium_form_field_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_form_field_list.md).
