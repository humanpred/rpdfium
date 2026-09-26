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

## Details

An existing appearance stream is not resized. PDFium, like other
viewers, draws an appearance by mapping its `/BBox` onto the
annotation's `/Rect` (ISO 32000-1:2008 section 12.5.5), so the
appearance is scaled to fill the new rectangle. Replace it with
[`pdf_annot_set_appearance()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_appearance.md)
if it should keep its size.

## See also

[`pdf_annot_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_bounds.md).
