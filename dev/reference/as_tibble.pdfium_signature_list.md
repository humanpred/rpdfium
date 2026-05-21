# Tibble view of a `pdfium_signature_list`

Walks every signature in the list and reads its metadata into a tibble.
Adds `handle` and `source` list-columns (ADR-017).

## Usage

``` r
# S3 method for class 'pdfium_signature_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_signature_list` from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble with the previous
[`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md)
columns plus `handle` and `source`.
