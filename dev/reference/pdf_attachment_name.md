# Attachment file name

Returns the filename declared in the attachment's `/F` (preferred) or
`/UF` entry. Wraps `FPDFAttachment_GetName`.

## Usage

``` r
pdf_attachment_name(att)
```

## Arguments

- att:

  A `pdfium_attachment` handle from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).

## Value

Character scalar (UTF-8). Empty string if no name.
