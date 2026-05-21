# Set the raw bytes of an embedded file attachment

Replaces the attachment's embedded file data with the given raw bytes.
Wraps `FPDFAttachment_SetFile`. The attachment's `CreationDate` and
checksum dictionary entries are automatically updated; **all other
entries** (including the MIME `Subtype` and the `Desc` you may have set
with
[`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_dict_value.md))
are cleared by PDFium during the write — set those entries *after* this
call.

## Usage

``` r
pdf_attachment_set_data(att, data)
```

## Arguments

- att:

  A `pdfium_attachment` from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md)
  or
  [`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_new.md).
  Parent doc must be readwrite.

- data:

  A raw vector of file bytes. To attach a UTF-8 text payload, pass
  `charToRaw(enc2utf8(text))`.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Use this immediately after
[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_new.md)
to populate a fresh attachment, or to update the file contents of an
existing one.

## See also

[`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_data.md)
for the read side.
