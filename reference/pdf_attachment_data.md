# Read the raw bytes of an embedded file attachment

Returns the decompressed file contents of the attachment at
`attachment_index` (1-based, as listed by
[`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md)).
Wraps `FPDFAttachment_GetFile`.

## Usage

``` r
pdf_attachment_data(doc, attachment_index = 1L)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- attachment_index:

  One-based index of the attachment in the document's attachment table.

## Value

A raw vector of file bytes.

## Details

Use the returned raw vector directly with
[`writeBin()`](https://rdrr.io/r/base/readBin.html) to save the embedded
file to disk without re-encoding, or pass it to a downstream parser
(e.g. `xml2::read_xml(rawToChar(bytes))` for XML attachments).

## See also

[`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md).
