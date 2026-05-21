# Set an entry in an attachment's `/Params` dictionary

Writes a string-valued entry in the attachment's parameter dictionary.
Common keys:

## Usage

``` r
pdf_attachment_set_dict_value(att, key, value)
```

## Arguments

- att:

  A `pdfium_attachment` from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md)
  or
  [`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md).
  Parent doc must be readwrite.

- key:

  The dictionary key as a non-empty character scalar.

- value:

  The string value as a character scalar; UTF-8 accepted.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

- `"Desc"` — a human-readable description.

- `"AFRelationship"` — the AF/EF relationship type (`"Source"`,
  `"Data"`, `"Alternative"`, etc.).

- `"ModDate"` — modification date as a PDF date string (see
  [`pdf_parse_date()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_parse_date.md)
  for the format).

Wraps `FPDFAttachment_SetStringValue`, which writes into the
attachment's `/Params` subdictionary. Mirrors
[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_dict_value.md)
on the read side.

**Ordering**: PDFium's `FPDFAttachment_SetStringValue` requires the
attachment's `/Params` dictionary to already exist. Call
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_data.md)
first on any attachment that doesn't have one yet (the file data write
auto-creates `/Params`, populating `Size`, `CreationDate`, and
`CheckSum`); only then can you append further keys with this function.
On a fresh attachment from
[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md)
this means the natural sequence is
[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md)
→
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_data.md)
→ `pdf_attachment_set_dict_value()`.

**Not exposed**: the file stream's own `/Subtype` entry (the MIME type
returned by
[`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_mime_type.md))
lives on the attachment's embedded file stream, not on `/Params`, and
PDFium has no public setter for it. Passing `key = "Subtype"` here
writes `/Params/Subtype`, which won't be picked up by
[`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_mime_type.md).
See `dev/upstream-patches/` for the upstream gap.

**Encoding**: PDFium's `FPDFAttachment_SetStringValue` stores the value
as a PDF byte-string interpreted in PDFDocEncoding on read. ASCII
round-trips cleanly; non-ASCII Unicode characters are lossy through the
read path (the bytes are written but `FPDFAttachment_GetStringValue`'s
`GetUnicodeText` step misinterprets multi-byte UTF-8 sequences as
PDFDocEncoding bytes). This is a PDFium-side inconsistency —
`FPDFAnnot_SetStringValue` uses the wide-string-aware CPDF_String path
and round-trips Unicode correctly. Until upstream is fixed, restrict
attachment-dict values to ASCII when round-trip fidelity matters.

## See also

[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_dict_value.md).
