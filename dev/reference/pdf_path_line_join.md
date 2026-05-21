# Stroke line-join style of a path page-object

Returns the PDF line-join style applied at corners along a stroked path.
Maps to the `LJ` operand and corresponds to PDFium's
`FPDFPageObj_GetLineJoin`.

## Usage

``` r
pdf_path_line_join(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

## Value

Character scalar; one of `"miter"` (sharp pointed corner, the PDF
default), `"round"` (circular arc at the corner), or `"bevel"` (flat
corner).

## See also

[`pdf_path_line_cap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_cap.md),
[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_stroke.md).
