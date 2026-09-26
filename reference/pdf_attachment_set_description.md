# Set the description of an embedded file attachment

Writes the `/Desc` entry of the attachment's file specification
dictionary (ISO 32000-1:2008 section 7.11.3) — the human-readable
description PDF viewers show in their attachments panel. Wraps
`FPDFAttachment_SetDescription`. Unlike the `/Params` entries written by
[`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_dict_value.md),
the description works on a fresh attachment before any data is set and
survives a later
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_data.md).

## Usage

``` r
pdf_attachment_set_description(att, value)
```

## Arguments

- att:

  A `pdfium_attachment` from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md)
  or
  [`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_new.md).
  Parent doc must be readwrite.

- value:

  Character scalar (UTF-8); `""` stores an empty description.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_attachment_description()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_description.md)
for the read side.
