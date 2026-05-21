# Annotation bounding rectangle

Returns the annotation's `/Rect` as a named numeric vector
(`bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top`) in PDF
user-space points. Wraps `FPDFAnnot_GetRect`. All four values are `NA`
when the annotation has no rectangle.

## Usage

``` r
pdf_annot_bounds(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md).

## Value

Named numeric of length 4.
