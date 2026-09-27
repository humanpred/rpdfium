# Close a PDF document

Releases the underlying PDFium handle. Idempotent — calling
`pdf_doc_close()` on an already-closed document is a no-op. The
finalizer registered at
[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md)
also calls this when the R object is garbage-collected, but explicit
close is recommended when handling many large documents or when a
subsequent operation needs to delete the source file (relevant on
Windows).

## Usage

``` r
pdf_doc_close(doc)
```

## Arguments

- doc:

  A `pdfium_doc` produced by
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md).

## Value

Invisibly returns `doc` with its underlying pointer marked closed.

## Details

Annotation handles still open on the document, including the form-field
handles of
[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md),
are closed first, because PDFium releases an annotation's resources only
while its document is open. Afterwards they print as closed, and
`pdf_annot_*()` calls on them raise an error.
