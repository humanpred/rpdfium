# Annotation quad points (attachment points)

Returns an `N x 8` numeric matrix of quad-point coordinates
(`x1, y1, x2, y2, x3, y3, x4, y4` columns; one row per quad), or `NULL`
when the annotation has no attachment points (most annotation types).

## Usage

``` r
pdf_annot_quad_points(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
  or
  [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_at.md).

## Value

Numeric matrix or `NULL`.

## Details

Wraps `FPDFAnnot_HasAttachmentPoints` +
`FPDFAnnot_CountAttachmentPoints` + `FPDFAnnot_GetAttachmentPoints`.
