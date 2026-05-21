# Coerce input to a `pdfium_attachment_list`

Reverse companion to
[`as_tibble.pdfium_attachment_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_attachment_list.md).

## Usage

``` r
as_pdfium_attachment_list(x)
```

## Arguments

- x:

  Either a `pdfium_attachment_list`, a plain list of `pdfium_attachment`
  handles, or a tibble with a `handle` list-column.

## Value

A `pdfium_attachment_list`.
