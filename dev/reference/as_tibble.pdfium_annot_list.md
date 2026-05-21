# Tibble view of a `pdfium_annot_list`

Walks the list of annotation handles and reads every documented
attribute into a wide tibble. The tibble carries two extra list-columns
relative to a simple data extraction:

## Usage

``` r
# S3 method for class 'pdfium_annot_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_annot_list` from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble with one row per annotation. Columns mirror the previous
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
tibble plus `handle` and `source`.

## Details

- `handle` — the original `pdfium_annot` handle for that row, so the
  round-trip back via
  [`as_pdfium_annot_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_pdfium_annot_list.md)
  preserves R-object identity.

- `source` — the parent `pdfium_page` for every row.
