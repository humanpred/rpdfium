# Form-field export value

Returns the field's PDF export value for checkbox / radio / button
fields (the `/V` value used when checked). Empty for non-applicable
field types. Wraps `FPDFAnnot_GetFormFieldExportValue`.

## Usage

``` r
pdf_form_field_export_value(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Character scalar.
