# Attachment relationship to the document (PDF 2.0)

Returns the `/AFRelationship` entry of the attachment's file
specification dictionary: how the embedded file relates to the PDF, one
of `"Source"`, `"Data"`, `"Alternative"`, `"Supplement"`,
`"EncryptedPayload"`, `"FormData"`, `"Schema"`, or `"Unspecified"` (ISO
32000-2:2020, Table 43). Associated-file relationships are how PDF/A-3
and e-invoice formats such as ZUGFeRD / Factur-X mark their
machine-readable payloads. Wraps `FPDFAttachment_GetAFRelationship`.

## Usage

``` r
pdf_attachment_af_relationship(att)
```

## Arguments

- att:

  A `pdfium_attachment` handle from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md).

## Value

Character scalar; empty when the entry is absent or not a PDF name.
