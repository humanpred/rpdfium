# Read the raw bytes of an embedded file attachment

Returns the decompressed file contents of the attachment. Wraps
`FPDFAttachment_GetFile`.

## Usage

``` r
pdf_attachment_data(att)
```

## Arguments

- att:

  A `pdfium_attachment` handle from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).

## Value

A raw vector of file bytes.

## Details

Use the returned raw vector directly with
[`writeBin()`](https://rdrr.io/r/base/readBin.html) to save the embedded
file to disk without re-encoding, or pass it to a downstream parser
(e.g. `xml2::read_xml(rawToChar(bytes))` for XML attachments).

## See also

[`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).
