# Transform the clip path of a page object

Wraps `FPDFPageObj_TransformClipPath`. Applies a 6-tuple affine
transform `(a, b, c, d, e, f)` to the existing clip path of a page
object — useful for scaling / rotating / translating a previously-set
clip without rebuilding it.

## Usage

``` r
pdf_obj_transform_clip_path(obj, matrix)
```

## Arguments

- obj:

  A `pdfium_obj` with an existing clip path.

- matrix:

  Numeric length-6 vector `c(a, b, c, d, e, f)`.

## Value

Invisibly returns the parent `pdfium_doc`.
