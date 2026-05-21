# Tibble-shaped summary of a page-object list

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_obj_list`. Defers to
[`as_tibble.pdfium_obj_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_obj_list.md)
so users can call `summary(pdf_page_objects(page))` for the standard
tibble view — matches the R idiom of
[`print()`](https://rdrr.io/r/base/print.html) for the one-line summary
and [`summary()`](https://rdrr.io/r/base/summary.html) for the deep
dive.

## Usage

``` r
# S3 method for class 'pdfium_obj_list'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_obj_list` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

- ...:

  Forwarded to
  [`as_tibble.pdfium_obj_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_obj_list.md).

## Value

The tibble returned by
[`as_tibble.pdfium_obj_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_obj_list.md).
