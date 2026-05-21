# Tibble-shaped summary of a signature list

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_signature_list`. Defers to
[`as_tibble.pdfium_signature_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_signature_list.md)
for the standard tibble view.

## Usage

``` r
# S3 method for class 'pdfium_signature_list'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_signature_list` from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md).

- ...:

  Forwarded to
  [`as_tibble.pdfium_signature_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_signature_list.md).

## Value

The tibble returned by
[`as_tibble.pdfium_signature_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_signature_list.md).
