# Tibble-shaped summary of an attachment list

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_attachment_list`. Defers to
[`as_tibble.pdfium_attachment_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_attachment_list.md)
for the standard tibble view — matches the R idiom of
[`print()`](https://rdrr.io/r/base/print.html) for the one-line summary
and [`summary()`](https://rdrr.io/r/base/summary.html) for the deep
dive.

## Usage

``` r
# S3 method for class 'pdfium_attachment_list'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_attachment_list` from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).

- ...:

  Forwarded to
  [`as_tibble.pdfium_attachment_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_attachment_list.md).

## Value

The tibble returned by
[`as_tibble.pdfium_attachment_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_attachment_list.md).
