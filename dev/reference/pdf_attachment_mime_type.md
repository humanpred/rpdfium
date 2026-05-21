# Attachment MIME / subtype

Returns the attachment's declared `/Subtype` (typically a MIME type such
as `"application/xml"`). Wraps `FPDFAttachment_GetSubtype`.

## Usage

``` r
pdf_attachment_mime_type(att)
```

## Arguments

- att:

  A `pdfium_attachment` handle from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).

## Value

Character scalar; empty if no subtype declared.
