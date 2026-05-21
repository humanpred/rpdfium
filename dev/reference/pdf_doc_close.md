# Close a PDF document

Releases the underlying PDFium handle. Idempotent — calling
`pdf_doc_close()` on an already-closed document is a no-op. The
finalizer registered at
[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md)
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
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md).

## Value

Invisibly returns `doc` with its underlying pointer marked closed.
