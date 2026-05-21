# Look up an attachment-dictionary entry by key

PDF attachments carry a `/Params` dictionary with metadata about the
embedded file (size, modification date, checksums, MIME type, custom
keys).
[`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md)
surfaces the common entries; this function reads an arbitrary key. Wraps
`FPDFAttachment_HasKey` + `FPDFAttachment_GetValueType` +
`FPDFAttachment_GetStringValue`.

## Usage

``` r
pdf_attachment_dict_value(att, key)
```

## Arguments

- att:

  A `pdfium_attachment` handle from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).

- key:

  The attachment-dict key as a single non-empty character string (e.g.
  `"Subtype"`, `"AFRelationship"`).

## Value

A list:

- `has_key` (logical) — `TRUE` when the attachment dict contains the
  key.

- `value_type` (integer) — PDFium's `FPDF_OBJECT_*` enum value; `NA`
  when the key is absent.

- `value` (character) — the string / name value; `NA_character_` when
  the value is not string-typed.

## Details

Only string- and name-typed values are returned as character scalars.
For numeric / boolean / dict values the function reports
`has_key = TRUE` and `value_type` accordingly but
`value = NA_character_` (use
[`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md)
for the structured size/date/checksum readouts).

## See also

[`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).
