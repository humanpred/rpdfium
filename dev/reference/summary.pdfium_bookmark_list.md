# Tibble-shaped summary of a bookmark list

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_bookmark_list`. Defers to
[`as_tibble.pdfium_bookmark_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_bookmark_list.md)
for the standard tibble view.

## Usage

``` r
# S3 method for class 'pdfium_bookmark_list'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_bookmark_list` from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md).

- ...:

  Forwarded to
  [`as_tibble.pdfium_bookmark_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_bookmark_list.md).

## Value

The tibble returned by
[`as_tibble.pdfium_bookmark_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_bookmark_list.md).
