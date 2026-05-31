# Attach a file to a file-attachment annotation

Wraps `FPDFAnnot_AddFileAttachment`. Adds a new file attachment to the
document (returning the `pdfium_attachment` handle) and links it to
`annot`. Use
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_data.md)
(or the related attachment-authoring setters) to populate the file
bytes.

## Usage

``` r
pdf_annot_add_file_attachment(annot, name)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"fileattachment"`.

- name:

  Character scalar — the file name to register in the document's
  `/Names` tree.

## Value

The new `pdfium_attachment` handle.

## See also

[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_new.md)
for the doc-level version.
