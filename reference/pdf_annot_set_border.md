# Set the border of an annotation

Wraps `FPDFAnnot_SetBorder`. The two corner radii produce rounded
rectangles when nonzero; `border_width` is the stroke width in PDF
user-space units.

## Usage

``` r
pdf_annot_set_border(
  annot,
  horizontal_radius = 0,
  vertical_radius = 0,
  border_width = 1
)
```

## Arguments

- annot:

  A `pdfium_annot`.

- horizontal_radius, vertical_radius:

  Numeric — corner radii in PDF user-space units. `0` for a square
  corner.

- border_width:

  Numeric — stroke width in PDF user-space units.

## Value

Invisibly returns the parent `pdfium_doc`.
