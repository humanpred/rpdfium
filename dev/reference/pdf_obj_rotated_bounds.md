# Rotated bounding quadpoints of a page object

For objects that have been rotated by a transformation matrix (e.g. text
drawn at an angle, or a placed image with a rotated Form XObject CTM),
the axis-aligned bounding box from
[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_bounds.md)
is loose. `pdf_obj_rotated_bounds()` returns the tighter rotated
rectangle as four corner points. Wraps `FPDFPageObj_GetRotatedBounds`.

## Usage

``` r
pdf_obj_rotated_bounds(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

## Value

A length-8 named numeric vector `c(x1, y1, x2, y2, x3, y3, x4, y4)` in
PDF user-space points, or all-`NA` when PDFium reports no bounds for
this object.

## Details

The four corners are returned in the order PDFium reports them:
`(x1, y1)` is lower-left, `(x2, y2)` lower-right, `(x3, y3)`
upper-right, `(x4, y4)` upper-left, where "lower" / "upper" are relative
to the rotated rectangle's own local axes (not the page).

## See also

[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_bounds.md)
for the cheaper axis-aligned box.
