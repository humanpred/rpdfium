# Coerce input to a `pdfium_signature_list`

Reverse companion to
[`as_tibble.pdfium_signature_list()`](https://humanpred.github.io/rpdfium/reference/as_tibble.pdfium_signature_list.md).

## Usage

``` r
as_pdfium_signature_list(x)
```

## Arguments

- x:

  Either a `pdfium_signature_list`, a list of `pdfium_signature`
  handles, or a tibble with a `handle` list-column.

## Value

A `pdfium_signature_list`.
