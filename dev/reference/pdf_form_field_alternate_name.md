# Form-field alternate (tooltip) name (`/TU`)

Returns the field's `/TU` alternate name (the human-readable label PDF
readers use as the field tooltip). Empty when absent. Wraps
`FPDFAnnot_GetFormFieldAlternateName`.

## Usage

``` r
pdf_form_field_alternate_name(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Character scalar.
