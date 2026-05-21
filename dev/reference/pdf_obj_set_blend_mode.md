# Set the blend mode of a page object

Wraps `FPDFPageObj_SetBlendMode`. PDF blend modes mirror the Porter-Duff
/ PDF 1.4 transparency spec. Allowed values: `"Normal"` (default),
`"Multiply"`, `"Screen"`, `"Overlay"`, `"Darken"`, `"Lighten"`,
`"ColorDodge"`, `"ColorBurn"`, `"HardLight"`, `"SoftLight"`,
`"Difference"`, `"Exclusion"`, `"Hue"`, `"Saturation"`, `"Color"`,
`"Luminosity"`.

## Usage

``` r
pdf_obj_set_blend_mode(obj, mode)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).
  Parent doc must be readwrite.

- mode:

  Character scalar; one of the 16 PDF blend mode names listed above.

## Value

Invisibly returns the parent `pdfium_doc`.
