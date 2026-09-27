# Tibble view of a `pdfium_form_field_list`

Walks the list of field handles and reads every documented AcroForm
property into a wide tibble. Adds two list-columns relative to a simple
data extraction: `handle` (the `pdfium_form_field` per row) and `source`
(the parent `pdfium_doc`).

## Usage

``` r
# S3 method for class 'pdfium_form_field_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_form_field_list` from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble with one row per field and columns:

- `field_index` integer - 1-based, document-wide ordering (page-major,
  then in-page annotation order).

- `page_num` integer - 1-based page the widget lives on.

- `field_type` character - one of `"pushbutton"`, `"checkbox"`,
  `"radiobutton"`, `"combobox"`, `"listbox"`, `"textfield"`,
  `"signature"`, or one of the XFA variants (`"xfa_*"`); `"unknown"` for
  non-AcroForm widgets PDFium can't classify.

- `field_flags` integer - raw PDF form-field flags bitmask (bit 1 =
  ReadOnly, bit 2 = Required, bit 3 = NoExport, bit 13 = Password for
  textfields, bit 16 = MultiLine for textfields, etc.; see PDF spec
  Table 226).

- `is_readonly`, `is_required`, `is_no_export` logical - decoded
  universal flag bits (bits 1, 2, 3) for convenience.

- `is_checked` logical - current state of the widget; `TRUE` / `FALSE`
  for `checkbox` / `radiobutton` fields, `NA` for every other field
  type.

- `control_count` integer - total number of widgets in this field's
  control group (`>= 1`; `> 1` for radio button groups with multiple
  physical widgets). `NA` if PDFium reports failure.

- `control_index` integer - 0-based position of this row's widget within
  its control group. For a checkbox or a standalone widget this is `0`.
  `NA` if PDFium reports failure.

- `name` character - fully qualified field name, the period-joined
  dotted path PDFium reports (e.g. `"address.city"`).

- `alternate_name` character - the field's user-facing label (the `/TU`
  entry), shown by viewers as a tooltip.

- `value` character - the field's current display value. For text fields
  this is the entered text. For combo / listbox fields this is the
  *label* of the selected option (use `export_value` for the underlying
  export name). For checkbox / radio fields this is the appearance-state
  name ("Off" or the on-state name).

- `export_value` character - the field's export value (`/V`). Same as
  `value` for text fields. For buttons, the value that gets submitted in
  form data (e.g. "Yes" for a checkbox, or the radio's on-state name).

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` - widget
  rectangle in PDF user space.

- `options` list-column of character vectors - the choice labels for
  `combobox` and `listbox` fields; empty character vector for other
  types.

- `is_option_selected` list-column of logical vectors, one element per
  option (matches `options`). `TRUE` when the option is currently
  selected. Empty for non-choice fields.

- `additional_actions_js` list-column of length-4 character vectors
  named `c("key_stroke", "format", "validate", "calculate")`. Each
  element is the JavaScript source string PDFium reports for the
  corresponding trigger event, or `""` when the trigger has no JS
  handler. Surfaced read-only here; v0.2.0 may expose a writer.

- `handle` list-column - the row's `pdfium_form_field`.

- `source` list-column - the parent `pdfium_doc`.

A 0-row tibble of the same schema when the list is empty.

## Details

Internally calls the existing bulk reader (`cpp_form_fields_list`) for
speed; per-row handles are pulled from the list itself so R-object
identity survives round-trip.
