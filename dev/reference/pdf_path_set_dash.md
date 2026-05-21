# Set the dash array + phase of a path stroke

Wraps `FPDFPageObj_SetDashArray`. Pass an empty vector to clear the dash
(continuous stroke).

## Usage

``` r
pdf_path_set_dash(obj, array, phase = 0)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- array:

  Numeric vector of dash lengths (alternating on / off in PDF points),
  or `numeric(0)` for a continuous stroke.

- phase:

  Numeric scalar; offset (in PDF points) into the dash pattern at which
  to start drawing. Default `0`.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_dash()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_dash.md).
