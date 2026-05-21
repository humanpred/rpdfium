# Form-field type codes \<-\> names

Form-field types are reported by `FPDFAnnot_GetFormFieldType` as
`FPDF_FORMFIELD_*` codes (0 = unknown, 1 = pushbutton, 2 = checkbox, 3 =
radiobutton, 4 = combobox, 5 = listbox, 6 = textfield, 7 = signature, 8
= xfa, and 9-15 for XFA-specific flavors).
[`pdf_form_field_type()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_type.md)
returns the name; these helpers expose the mapping.

## Usage

``` r
pdfium_form_field_type_name(codes)

pdfium_form_field_type_code(names)
```

## Arguments

- codes:

  Integer vector of PDFium subtype codes.

- names:

  Character vector of subtype names (case-insensitive).

## Value

A character vector (`_name()`) or integer vector (`_code()`), same
length as the input.

## See also

[`pdf_form_field_type()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_type.md),
[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

## Examples

``` r
pdfium_form_field_type_name(c(2L, 6L, 4L))
#> [1] "checkbox"  "textfield" "combobox" 
#> [1] "checkbox" "textfield" "combobox"
pdfium_form_field_type_code(c("checkbox", "Textfield", "listbox"))
#> [1] 2 6 5
#> [1] 2 6 5
```
