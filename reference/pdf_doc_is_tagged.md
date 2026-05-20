# Is the document marked as tagged?

Reports whether the PDF catalog's `/MarkInfo` entry advertises the
document as tagged (i.e., it carries a structure tree usable for
accessibility/reflow). Wraps `FPDFCatalog_IsTagged`. Note that a
"tagged" advertisement is not a guarantee that the structure tree is
well-formed.

## Usage

``` r
pdf_doc_is_tagged(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

Logical scalar.
