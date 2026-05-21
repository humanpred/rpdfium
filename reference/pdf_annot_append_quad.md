# Append a quad to an annotation's `/QuadPoints` array

Wraps `FPDFAnnot_AppendAttachmentPoints`. Each quad is four `(x, y)`
points giving the corners of a tile in counterclockwise order (matching
the shape
[`pdf_annot_quad_points()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_quad_points.md)
reads back). For highlight / underline / squiggly / strikeout
annotations a quad covers each affected text run; a typical
paragraph-spanning highlight has one quad per visual line.

## Usage

``` r
pdf_annot_append_quad(annot, quad)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- quad:

  Length-8 numeric vector `c(x1, y1, x2, y2, x3, y3, x4, y4)`.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_quad_points()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_quad_points.md).
