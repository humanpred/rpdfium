# Coerce input to a `pdfium_bookmark_list`

Reverse companion to
[`as_tibble.pdfium_bookmark_list()`](https://humanpred.github.io/rpdfium/reference/as_tibble.pdfium_bookmark_list.md).

## Usage

``` r
as_pdfium_bookmark_list(x)
```

## Arguments

- x:

  Either a `pdfium_bookmark_list`, a list of `pdfium_bookmark` handles,
  or a tibble with a `handle` list-column.

## Value

A `pdfium_bookmark_list`.
