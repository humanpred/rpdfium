# Attachment decompressed size in bytes

Returns the embedded file's decompressed byte size, or `NA` when PDFium
reports the contents are unreadable.

## Usage

``` r
pdf_attachment_size_bytes(att)
```

## Arguments

- att:

  A `pdfium_attachment` handle from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md).

## Value

Numeric scalar.
