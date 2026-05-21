# Set the fill color of a path page object

Composite setter — accepts named partial updates. Wraps
`FPDFPageObj_SetFillColor`. Color accepts 0-255 ints or 0-1 doubles
(ADR-018 §5).

## Usage

``` r
pdf_path_set_fill(
  obj,
  color = NULL,
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

- red, green, blue, alpha:

  Individual channel overrides. Useful when you want to tweak one
  component without restating the rest.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_fill()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_fill.md).
