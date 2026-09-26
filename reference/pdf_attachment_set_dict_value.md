# Set an entry in an attachment's `/Params` dictionary

Writes a string-valued entry in the attachment's embedded-file parameter
dictionary (`/Params`, ISO 32000-1:2008 Table 46). The string-valued
standard key is `"ModDate"` — the modification date as a PDF date string
(see
[`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
for the format); custom keys are allowed too.

## Usage

``` r
pdf_attachment_set_dict_value(att, key, value)
```

## Arguments

- att:

  A `pdfium_attachment` from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md)
  or
  [`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_new.md).
  Parent doc must be readwrite.

- key:

  The dictionary key as a non-empty character scalar.

- value:

  The string value as a character scalar; UTF-8 accepted.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

The description (`/Desc`) and the associated-file relationship
(`/AFRelationship`) are *not* `/Params` entries: they live on the
attachment's file specification dictionary. Set the description with
[`pdf_attachment_set_description()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_description.md)
and read both with
[`pdf_attachment_description()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_description.md)
/
[`pdf_attachment_af_relationship()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_af_relationship.md).

Wraps `FPDFAttachment_SetStringValue`, which writes into the
attachment's `/Params` subdictionary. Mirrors
[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_dict_value.md)
on the read side.

**Ordering**: PDFium's `FPDFAttachment_SetStringValue` requires the
attachment's `/Params` dictionary to already exist. Call
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_data.md)
first on any attachment that doesn't have one yet (the file data write
auto-creates `/Params`, populating `Size`, `CreationDate`, and
`CheckSum`); only then can you append further keys with this function.
On a fresh attachment from
[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_new.md)
this means the natural sequence is
[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_new.md)
→
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_data.md)
→ `pdf_attachment_set_dict_value()`.

**Not exposed**: the file stream's own `/Subtype` entry (the MIME type
returned by
[`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_mime_type.md))
lives on the attachment's embedded file stream, not on `/Params`, and
PDFium has no public setter for it. Passing `key = "Subtype"` here
writes `/Params/Subtype`, which won't be picked up by
[`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_mime_type.md).
See `dev/upstream-patches/` for the upstream gap.

**Encoding**: values are written as PDF text strings, so any Unicode
text round-trips through
[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_dict_value.md)
and a save / reload. (PDFium releases before chromium/8066 stored the
raw UTF-8 bytes, which read back garbled for non-ASCII text.)

## See also

[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_dict_value.md).
