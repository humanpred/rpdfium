# Form-field current value (`/V`)

Returns the field's current value as text. For checkbox / radio fields
this is the export name when checked or `"Off"` otherwise. Wraps
`FPDFAnnot_GetFormFieldValue`.

## Usage

``` r
pdf_form_field_value(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Character scalar.
