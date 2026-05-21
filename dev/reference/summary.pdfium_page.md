# Page-level summary

[`summary()`](https://rdrr.io/r/base/summary.html) method for
`pdfium_page`. Returns a single-row tibble combining the cheap by-index
columns
([`pdf_pages_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_summary.md)-style:
`page_num`, `width`, `height`, `rotation`, `label`) with the per-page
counts that require the page to be loaded — annotation count,
page-object count, text-run count, and link count. Because the page
handle is already loaded, the per-count readers run against the existing
page and don't trigger an additional load.

## Usage

``` r
# S3 method for class 'pdfium_page'
summary(object, ...)
```

## Arguments

- object:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A one-row tibble with columns `page_num`, `width`, `height`, `rotation`,
`label`, `annotation_count`, `obj_count`, `text_run_count`,
`link_count`.

## Details

Use this for the "what's on this page?" interactive triage flow. For the
doc-wide companion, see
[`summary.pdfium_doc()`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_doc.md).

## See also

[`summary.pdfium_doc()`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_doc.md)
for the doc-wide companion,
[`pdf_pages_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_summary.md)
for the per-document table without the page-loaded counts.
