# Coerce input to a `pdfium_form_field_list`

Reverse companion to
[`as_tibble.pdfium_form_field_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_form_field_list.md).

## Usage

``` r
as_pdfium_form_field_list(x)
```

## Arguments

- x:

  Either a `pdfium_form_field_list`, a plain list of `pdfium_form_field`
  handles, or a tibble with a `handle` list-column.

## Value

A `pdfium_form_field_list`.
