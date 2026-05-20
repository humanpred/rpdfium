# Transformation matrix of a page object

Returns the 2D affine transformation matrix attached to `obj` as a
3-by-3 numeric matrix `M` in homogeneous form, so that a point `(x, y)`
in the object's local space maps to page-space coordinates via
`M %*% c(x, y, 1)`. The PDF convention stores the six scalars `a`, `b`,
`c`, `d`, `e`, `f`; this function lifts them into the
homogeneous-coordinate matrix

## Usage

``` r
pdf_obj_matrix(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
  (any type).

## Value

A 3-by-3 numeric matrix. Use `M %*% c(x, y, 1)` to transform a point;
the first two elements of the result are the transformed coordinates.

## Details

            | a c e |
      M  =  | b d f |
            | 0 0 1 |

so multiplication composes the way users expect (`M2 %*% M1` applies
`M1` first then `M2`). For paths drawn directly on a page the matrix is
usually the identity; text objects typically carry a non-trivial matrix
(Cairo for example places text at font-size 1 and uses the matrix to
scale and position the glyphs).

## See also

[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md),
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  p <- pdf_page_load(doc, 1)
  M <- pdf_obj_matrix(pdf_page_objects(p)[[1]])
  M %*% c(10, 20, 1)
  pdf_page_close(p)
  pdf_doc_close(doc)
}
```
