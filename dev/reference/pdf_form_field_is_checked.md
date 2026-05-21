# Form-field checked state

Returns `TRUE` / `FALSE` for checkbox / radiobutton fields, `NA` for
other field types. The check honours the current selection state PDFium
tracks; it falls back to inferring `TRUE` when the field value is
non-empty and not the `"Off"` sentinel (matching the tibble view's
inferred-checked logic). Wraps `FPDFAnnot_IsChecked`.

## Usage

``` r
pdf_form_field_is_checked(field)
```

## Arguments

- field:

  A `pdfium_form_field` handle from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).

## Value

Logical scalar or `NA`.
