# Set just the dash phase of a path object

Wraps `FPDFPageObj_SetDashPhase`. The full dash setter
[`pdf_path_set_dash()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_dash.md)
sets both the array and the phase in one call; this fine-grained setter
is useful when you want to tweak the phase without re-supplying the
(possibly-long) array.

## Usage

``` r
pdf_path_set_dash_phase(path, phase)
```

## Arguments

- path:

  A `pdfium_obj` of `type = "path"`.

- phase:

  Numeric — dash phase in PDF user-space units.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_set_dash()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_dash.md)
for the array + phase setter.
