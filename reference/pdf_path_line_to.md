# Append a LineTo command to a path object

Wraps `FPDFPath_LineTo`. Draws a straight line from the path's current
point to `(x, y)`, advancing the current point.

## Usage

``` r
pdf_path_line_to(obj, x, y)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- x, y:

  Numeric scalars in PDF user-space points (origin at the page's
  bottom-left).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_move_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_move_to.md),
[`pdf_path_bezier_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_bezier_to.md),
[`pdf_path_close()`](https://humanpred.github.io/rpdfium/reference/pdf_path_close.md),
[`pdf_path_append()`](https://humanpred.github.io/rpdfium/reference/pdf_path_append.md).
