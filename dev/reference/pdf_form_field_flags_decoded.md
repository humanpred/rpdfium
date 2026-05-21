# Form-field universal flag bits, decoded

Decodes the three universal AcroForm flag bits (ReadOnly, Required,
NoExport) into a named logical vector.

## Usage

``` r
pdf_form_field_flags_decoded(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Named logical vector with elements `is_readonly`, `is_required`,
`is_no_export`.

## See also

[`pdf_form_field_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_flags.md).
