# Clear a form field to its default value

Restores `/V` to the field's `/DV` entry (the dictionary's "default
value"). If `/DV` is absent, writes the type- appropriate empty:

## Usage

``` r
pdf_form_field_clear(field)
```

## Arguments

- field:

  A `pdfium_form_field` from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).
  Parent doc must be readwrite.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

- Text / choice: empty string.

- Checkbox / radio: `"Off"` and mirrors `/AS` to match.

Wraps `FPDFAnnot_GetStringValue(annot, "DV", ...)` +
[`pdf_form_field_set_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_set_value.md).

## See also

[`pdf_form_reset()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_reset.md)
for the doc-wide variant.
