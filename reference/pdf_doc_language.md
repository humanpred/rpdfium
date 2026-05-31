# Get the document's declared language

Reads the PDF catalog's `/Lang` entry — the document's declared natural
language as a BCP-47 tag (e.g. `"en"`, `"en-US"`). Wraps
`FPDFCatalog_GetLanguage` (PDFium chromium/7857+), the reader
counterpart to
[`pdf_doc_set_language()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_set_language.md).

## Usage

``` r
pdf_doc_language(doc, password = NULL)
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

Character scalar — the BCP-47 language tag, or `""` when the document
declares no `/Lang`.

## See also

[`pdf_doc_set_language()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_set_language.md)
to write it.
