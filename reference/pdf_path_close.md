# Close the current subpath of a path object

Wraps `FPDFPath_Close`. Draws a straight line from the current point
back to the most recent `MoveTo` and marks the subpath as closed (so
stroking joins the ends correctly and filling respects the closed
region).

## Usage

``` r
pdf_path_close(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_move_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_move_to.md),
[`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_line_to.md),
[`pdf_path_bezier_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_bezier_to.md),
[`pdf_path_append()`](https://humanpred.github.io/rpdfium/reference/pdf_path_append.md).
