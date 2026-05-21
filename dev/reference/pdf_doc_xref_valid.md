# Cross-reference table validity flag

Returns `TRUE` when the document's `/XRef` table is structurally valid
as PDFium found it, or `FALSE` when PDFium had to rebuild it from
scratch (a sign of a damaged or non-conforming PDF). Wraps
`FPDF_DocumentHasValidCrossReferenceTable`.

## Usage

``` r
pdf_doc_xref_valid(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

## Value

Logical scalar.
