# Number of controls in this radio group (or NA)

For a radio button widget, returns the number of siblings in its group;
`NA` otherwise. Wraps `FPDFAnnot_GetFormControlCount`.

## Usage

``` r
pdf_form_field_control_count(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Integer scalar or `NA`.
