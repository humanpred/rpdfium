# List the files attached to a PDF document

Returns a tibble row per `/EmbeddedFile` object in the document. Wraps
`FPDFDoc_GetAttachmentCount`, `FPDFDoc_GetAttachment`,
`FPDFAttachment_GetName`, `FPDFAttachment_GetSubtype`, and
`FPDFAttachment_GetFile`'s size-query form.

## Usage

``` r
pdf_attachments(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

## Value

A tibble with columns:

- `attachment_index` integer - 1-based index into the document's
  attachment table; pass this to
  [`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_data.md)
  to read the file's bytes.

- `name` character - filename declared in the attachment's `/F`
  (preferred) or `/UF` entry.

- `mime_type` character - the attachment's `/Subtype` (e.g.
  `"application/xml"`, `"image/png"`). Empty string if none declared.

- `size_bytes` numeric - the embedded file's decompressed byte size.
  `NA` when PDFium reports the contents are unreadable.

Returns a 0-row tibble of the same schema when the document has no
attachments.

## See also

[`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_data.md).

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) pdf_attachments(fixture)
#> # A tibble: 0 × 4
#> # ℹ 4 variables: attachment_index <int>, name <chr>, mime_type <chr>,
#> #   size_bytes <dbl>
```
