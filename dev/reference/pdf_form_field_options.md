# Form-field option labels (combobox / listbox)

Returns a character vector of option labels, one per choice in a
combobox / listbox field. Empty for non-choice fields. Wraps
`FPDFAnnot_GetOptionCount` + `FPDFAnnot_GetOptionLabel`.

## Usage

``` r
pdf_form_field_options(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Character vector (possibly empty).
