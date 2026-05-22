# Append an ink stroke to an ink annotation

Wraps `FPDFAnnot_AddInkStroke`. The `points` matrix carries the stroke
as Nx2 (`x`, `y`) in PDF user-space points; PDFium creates a fresh
ink-list entry if the annotation doesn't already have one.

## Usage

``` r
pdf_annot_add_ink_stroke(annot, points)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"ink"`.

- points:

  Numeric matrix with two columns (`x`, `y`).

## Value

Invisibly returns the integer stroke index (one-based) of the
newly-added stroke. `-1L` on failure.

## See also

[`pdf_annot_remove_ink_list()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_remove_ink_list.md)
to clear all strokes.
