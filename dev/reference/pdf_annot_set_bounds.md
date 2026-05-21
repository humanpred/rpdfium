# Set the bounding rectangle of an annotation

Wraps `FPDFAnnot_SetRect`. Replaces the `/Rect` entry with the given
`(left, bottom, right, top)` in PDF user-space points.

## Usage

``` r
pdf_annot_set_bounds(annot, bounds)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- bounds:

  Length-4 numeric vector `c(left, bottom, right, top)`.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_bounds.md).
