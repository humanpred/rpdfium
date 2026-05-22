# Set the form-field flag bitmask on a form-field widget

Wraps `FPDFAnnot_SetFormFieldFlags`. Pair with the existing
[`pdf_form_field_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_flags.md)
reader.

## Usage

``` r
pdf_form_field_set_flags(field, flags)
```

## Arguments

- field:

  A `pdfium_form_field` from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

- flags:

  Integer bitmask of `FPDF_FORMFLAG_*` values.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_form_field_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_flags.md).
