# Tibble view of a `pdfium_attachment_list`

Walks every attachment in the list and reads its name / mime-type /
size-bytes into a tibble. Adds `handle` and `source` list-columns
(ADR-017).

## Usage

``` r
# S3 method for class 'pdfium_attachment_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_attachment_list` from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble with columns `attachment_index`, `name`, `mime_type`,
`size_bytes`, `description`, `af_relationship`, `handle`, `source`.
`description` and `af_relationship` are empty strings when the
attachment doesn't declare them (see
[`pdf_attachment_description()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_description.md),
[`pdf_attachment_af_relationship()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_af_relationship.md)).

## Details

Internally calls the existing bulk reader (`cpp_attachments_list`) for
speed.
