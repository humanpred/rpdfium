# Set the stroke style of a path page object

Composite setter — accepts named partial updates. Any argument left
`NULL` keeps its current value. Wraps `FPDFPageObj_SetStrokeColor` +
`FPDFPageObj_SetStrokeWidth`.

## Usage

``` r
pdf_path_set_stroke(
  obj,
  color = NULL,
  width = NULL,
  red = NULL,
  green = NULL,
  blue = NULL,
  alpha = NULL
)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- color:

  Length-3 (RGB) or length-4 (RGBA) numeric vector, or `NULL` to keep
  the current color.

- width:

  Stroke width in points, or `NULL`.

- red, green, blue, alpha:

  Individual channel overrides. Useful when you want to tweak one
  component without restating the rest.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Color accepts either 0-255 integers or 0-1 doubles (ADR-018 §5); the
form is auto-detected from the input range.

## See also

[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_stroke.md).
