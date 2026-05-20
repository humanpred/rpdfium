# Tibble view of a `pdfium_form_field_list`

Walks the list of field handles and reads every documented AcroForm
property into a wide tibble. Adds two list-columns relative to a simple
data extraction: `handle` (the `pdfium_form_field` per row) and `source`
(the parent `pdfium_doc`).

## Usage

``` r
# S3 method for class 'pdfium_form_field_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_form_field_list` from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble matching the previous
[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md)
shape plus `handle` + `source` columns.

## Details

Internally calls the existing bulk reader (`cpp_form_fields_list`) for
speed; per-row handles are pulled from the list itself so R-object
identity survives round-trip.
