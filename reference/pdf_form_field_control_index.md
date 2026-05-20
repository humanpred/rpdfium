# 1-based index of this control within its radio group

For a radio button widget, returns this control's 1-based index among
its siblings; `NA` otherwise. Wraps `FPDFAnnot_GetFormControlIndex`
(1-based conversion applied).

## Usage

``` r
pdf_form_field_control_index(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

## Value

Integer scalar or `NA`.
