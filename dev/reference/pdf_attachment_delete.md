# Delete an embedded file attachment from a document

Removes the attachment's entry from the document's `/EmbeddedFiles` name
tree. Wraps `FPDFDoc_DeleteAttachment`. The handle becomes closed
(subsequent reads / writes through it error cleanly); indexes of any
later attachments shift down by one in PDFium's internal list — re-fetch
via
[`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md)
if you held other handles past this point.

## Usage

``` r
pdf_attachment_delete(att)
```

## Arguments

- att:

  A `pdfium_attachment` from
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md)
  or
  [`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md).
  Parent doc must be readwrite.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Note: PDFium's delete only removes the name-tree pointer; the underlying
`/EmbeddedFile` object may still occupy bytes in the saved PDF. This
matches `FPDFDoc_DeleteAttachment`'s documented behaviour.

## See also

[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md).
