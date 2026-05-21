# Annotation vertices (polygon / polyline)

Returns an `N x 2` numeric matrix (columns `x`, `y`) of the annotation's
`/Vertices` entry, or `NULL` when absent. Wraps `FPDFAnnot_GetVertices`.

## Usage

``` r
pdf_annot_vertices(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
  or
  [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_at.md).

## Value

Numeric matrix or `NULL`.
