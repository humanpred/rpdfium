# Construct a `pdfium_annot` handle for one annotation

Looks up the annotation at `annotation_index` on `page` and returns a
handle. Wraps `FPDFPage_GetAnnot`.

## Usage

``` r
pdf_annot_at(page, annotation_index, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` or `pdfium_doc`.

- annotation_index:

  One-based annotation index on the page.

- page_num:

  One-based page index (only used when `page` is a `pdfium_doc`).

## Value

A `pdfium_annot` handle.

## Details

Most callers don't need this directly —
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
returns the full list of handles. `pdf_annot_at()` is the targeted
lookup, useful when you have an index from a tibble row.
