# Form-field flag bitmask (`/Ff`)

Returns the raw PDF AcroForm flag bitmask. See PDF spec Table 226/227
for bit semantics; common bits include `ReadOnly` (1), `Required` (2),
`NoExport` (3). Use
[`pdf_form_field_flags_decoded()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_flags_decoded.md)
for the named-logical view. Wraps `FPDFAnnot_GetFormFieldFlags`.

## Usage

``` r
pdf_form_field_flags(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

## Value

Integer scalar.
