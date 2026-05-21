# Tibble view of a `pdfium_bookmark_list`

Walks every bookmark in the list and reads its metadata into a tibble.
Adds `handle` and `source` list-columns (ADR-017).

## Usage

``` r
# S3 method for class 'pdfium_bookmark_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_bookmark_list` from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble with the documented bookmark columns plus `handle` and
`source`.
