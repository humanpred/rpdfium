# Attachment description

Returns the human-readable description of the embedded file: the `/Desc`
entry of its file specification dictionary (ISO 32000-1:2008 section
7.11.3). Wraps `FPDFAttachment_GetDescription`.

## Usage

``` r
pdf_attachment_description(att)
```

## Arguments

- att:

  A `pdfium_attachment` handle from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md).

## Value

Character scalar (UTF-8); empty when the attachment has no `/Desc`, or
its `/Desc` is not a string.

## See also

[`pdf_attachment_set_description()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_description.md)
for the write side.
