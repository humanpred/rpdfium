# Form-field JavaScript additional-action sources

Returns a named character vector with the JS source attached to each of
the four `additional action` events PDFium exposes for AcroForm fields.
Empty strings when no JS is attached. Wraps
`FPDFAnnot_GetFormAdditionalActionJavaScript`.

## Usage

``` r
pdf_form_field_additional_actions_js(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

## Value

Character vector of length 4, named
`c("key_stroke", "format", "validate", "calculate")`.
