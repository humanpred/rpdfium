# Transformation matrix of a page object

Returns the 2D affine transformation matrix attached to `obj`, as a
length-6 named numeric vector `c(a, b, c, d, e, f)`. The matrix follows
the PDF convention: a point `(x, y)` in the object's local space maps to
page-space coordinates `(a*x + c*y + e, b*x + d*y + f)`. For paths drawn
directly on a page the matrix is usually the identity; text objects
typically carry a non-trivial matrix (Cairo for example places text at
font-size 1 and uses the matrix to scale and position the glyphs).

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

A named numeric vector with elements `a`, `b`, `c`, `d`, `e`, `f`.

## Details

Composing into a 3x3 matrix:

    m <- pdf_obj_matrix(obj)
    mat <- matrix(c(m["a"], m["b"], 0,
                    m["c"], m["d"], 0,
                    m["e"], m["f"], 1),
                  nrow = 3, byrow = FALSE)

## See also

[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md),
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  p <- pdf_load_page(doc, 1)
  pdf_obj_matrix(pdf_page_objects(p)[[1]])
  pdf_close_page(p)
  pdf_close(doc)
}
```
