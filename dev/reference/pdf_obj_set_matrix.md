# Set the affine transformation matrix of a page object

Wraps `FPDFPageObj_SetMatrix`. Replaces the page object's current
transformation matrix (CTM) with the given 2D affine transform. Accepts
either a 3x3 homogeneous matrix (matching the shape
[`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_matrix.md)
returns) or a length-6 vector `c(a, b, c, d, e, f)` in PDF column-major
order.

## Usage

``` r
pdf_obj_set_matrix(obj, matrix)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).
  Parent doc must be readwrite.

- matrix:

  Either a 3x3 numeric matrix (with bottom row `(0, 0, 1)`) or a
  length-6 numeric vector.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_matrix.md)
for the read side.
