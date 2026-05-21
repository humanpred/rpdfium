# Set the value of a form field

Polymorphic setter: the semantics depend on the field's type.

## Usage

``` r
pdf_form_field_set_value(field, value)
```

## Arguments

- field:

  A `pdfium_form_field` from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md).
  Parent doc must be readwrite.

- value:

  Character scalar OR logical scalar (for checkable types). See
  type-specific rules above.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

- **Text** (`"textfield"`, `"xfa_textfield"`): `value` must be a
  character scalar. Sets `/V` directly.

- **Checkbox / radio** (`"checkbox"`, `"radiobutton"`,
  `"xfa_checkbox"`): `value` may be either a logical scalar or a
  character scalar. `TRUE` writes the field's on-state name (inferred
  from the current `/V` or `/AS`, falling back to `"Yes"`); `FALSE`
  writes `"Off"`. A character value is written literally — useful when
  you already know the export-value string and want to bypass inference.

- **Combobox / listbox** (`"combobox"`, `"listbox"`, `"xfa_combobox"`,
  `"xfa_listbox"`): `value` must be a character scalar matching one of
  the field's options
  ([`pdf_form_field_options()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_options.md)).

Any other field type (button / signature / unknown) errors — those don't
have a settable value.

Wraps `FPDFAnnot_SetStringValue(annot, "V", ...)` followed by a rect
re-touch (`FPDFAnnot_SetRect` to the current rect) that flips the
AP-dirty flag, so the next
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md)
or
[`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md)
rebuilds the widget's appearance stream from the new value.

## See also

[`pdf_form_field_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_value.md),
[`pdf_form_field_clear()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_clear.md),
[`pdf_form_reset()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_reset.md).
