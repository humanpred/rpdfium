# Annotation ink paths (ink strokes)

Returns a list of `N x 2` numeric matrices, one per stroke in an ink
annotation's `/InkList`, or `NULL` when the annotation is not an ink
type. Wraps `FPDFAnnot_GetInkListCount` + `FPDFAnnot_GetInkListPath`.

## Usage

``` r
pdf_annot_ink_paths(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
  or
  [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_at.md).

## Value

List of numeric matrices or `NULL`.
