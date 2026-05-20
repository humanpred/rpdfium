# Coerce input to a `pdfium_annot_list`

Reverse companion to
[`as_tibble.pdfium_annot_list()`](https://humanpred.github.io/rpdfium/reference/as_tibble.pdfium_annot_list.md):
takes either an existing list of `pdfium_annot` handles or a tibble
produced by `as_tibble()` and returns a `pdfium_annot_list`.

## Usage

``` r
as_pdfium_annot_list(x)
```

## Arguments

- x:

  Either a `pdfium_annot_list`, a list of `pdfium_annot` handles, or a
  tibble with a `handle` list-column.

## Value

A `pdfium_annot_list`.
