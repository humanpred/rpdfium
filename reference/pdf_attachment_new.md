# Add a new embedded file attachment to a document

Creates a new `/EmbeddedFile` entry in `doc`'s name tree, with the given
filename. The returned handle is a `pdfium_attachment` that you can pass
to
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_data.md)
to populate the file bytes, and
[`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_dict_value.md)
to populate dictionary metadata (`"Subtype"`, `"Desc"`, etc.).

## Usage

``` r
pdf_attachment_new(doc, name)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md)
  or
  [`pdf_doc_new()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_new.md).
  Must be readwrite.

- name:

  Character scalar — the attachment's filename. UTF-8 accepted.

## Value

A `pdfium_attachment` handle. The attachment is empty — call
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_data.md)
to populate its contents.

## Details

Wraps `FPDFDoc_AddAttachment`. The new attachment is appended to the end
of the document's existing attachment list, and its `$index` field
reflects the resulting 1-based index. PDFium will refuse the creation
(returning `NULL`, which we surface as an R error) if:

- `name` is empty;

- `name` is the name of an existing embedded file in `doc`;

- the document's name tree is at its depth limit.

## See also

[`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md)
for the read side,
[`pdf_attachment_delete()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_delete.md)
to remove an attachment.
