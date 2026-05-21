# Append a cubic Bezier curve to a path object

Wraps `FPDFPath_BezierTo`. Draws a cubic Bezier curve from the path's
current point to `(x3, y3)`, with control points `(x1, y1)` and
`(x2, y2)`. The PDF operator emitted is `c`.

## Usage

``` r
pdf_path_bezier_to(obj, x1, y1, x2, y2, x3, y3)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- x1, y1:

  First control point.

- x2, y2:

  Second control point.

- x3, y3:

  Curve endpoint (becomes the new current point).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_move_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_move_to.md),
[`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_to.md),
[`pdf_path_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_close.md),
[`pdf_path_append()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_append.md).
