# Annotation subtype (string)

Returns the annotation's subtype as a short name (`"text"`, `"link"`,
`"freetext"`, …). Wraps `FPDFAnnot_GetSubtype`.

## Usage

``` r
pdf_annot_subtype(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).

## Value

Character scalar; one of the 29 PDFium annotation subtype names, or
`"unknown"`.
