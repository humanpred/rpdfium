# Document-level summary

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_doc`. Defers to
[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
so users can call `summary(doc)` for the single-row tibble of every key
fact about the PDF — page count, Info-dictionary metadata, structural
feature flags, per-feature counts, the file-ID tuple — in one call.

## Usage

``` r
# S3 method for class 'pdfium_doc'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md).

- ...:

  Unused (S3 generic compatibility).

## Value

The tibble returned by
[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md).

## See also

[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md).
