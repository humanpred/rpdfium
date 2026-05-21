# Form-field name (`/T`)

Returns the field's fully-qualified `/T` name, UTF-8. Wraps
`FPDFAnnot_GetFormFieldName`. Empty string when the doc has no AcroForm
dict.

## Usage

``` r
pdf_form_field_name(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Character scalar.
