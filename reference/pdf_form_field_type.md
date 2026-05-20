# Form-field type (string)

Returns the AcroForm field type as a short name. Wraps
`FPDFAnnot_GetFormFieldType`.

## Usage

``` r
pdf_form_field_type(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

## Value

Character scalar; one of `"unknown"`, `"pushbutton"`, `"checkbox"`,
`"radiobutton"`, `"combobox"`, `"listbox"`, `"text"`, `"signature"`.
