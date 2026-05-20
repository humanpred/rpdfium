# Enumerate AcroForm fields across the whole document

Returns one tibble row per form widget across every page of the
document. Walks each page's annotations, filters to those of subtype
`widget`, and reads PDFium's form-field metadata through a transient
`FPDF_FORMHANDLE` (init / enumerate / teardown happens inside one call -
the handle is not exposed to R).

## Usage

``` r
pdf_form_fields(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

## Value

A tibble with columns:

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
  control group (≥ 1; `> 1` for radio button groups with multiple
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

Returns a 0-row tibble of the same schema when the document has no
AcroForm dictionary.

## Details

Wraps `FPDFDOC_InitFormFillEnvironment`,
`FPDFDOC_ExitFormFillEnvironment`, the `FPDFAnnot_GetFormField*` family,
`FPDFAnnot_IsChecked` for the check/radio state, and
`FPDFAnnot_GetOption*` for choice-list options.

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
for the page-level annotation surface that includes widget annotations
alongside text, highlights, ink, etc.
