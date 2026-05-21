# Form-field option selected-state (combobox / listbox)

Returns a logical vector parallel to
[`pdf_form_field_options()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_options.md)
reporting which options are currently selected. Wraps
`FPDFAnnot_IsOptionSelected`.

## Usage

``` r
pdf_form_field_is_option_selected(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Logical vector (possibly empty).
