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

- `field_flags` integer - PDF form-field flags bitmask (bit 1 =
  ReadOnly, bit 2 = Required, bit 3 = NoExport, bit 13 = Password for
  textfields, bit 16 = MultiLine for textfields, etc.; see PDF spec
  Table 226).

- `name` character - fully qualified field name, the period-joined
  dotted path PDFium reports (e.g. `"address.city"`).

- `alternate_name` character - the field's user-facing label (the `/TU`
  entry), shown by viewers as a tooltip.

- `value` character - the field's current value as a string (text
  fields), the selected option label (combo/listbox), or the export
  value (check / radio).

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` - widget
  rectangle in PDF user space.

- `options` list-column of character vectors - the choice labels for
  `combobox` and `listbox` fields; empty character vector for other
  types.

Returns a 0-row tibble of the same schema when the document has no
AcroForm dictionary.

## Details

Wraps `FPDFDOC_InitFormFillEnvironment`,
`FPDFDOC_ExitFormFillEnvironment`, the `FPDFAnnot_GetFormField*` family,
and `FPDFAnnot_GetOption*` for choice-list options.

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
for the page-level annotation surface that includes widget annotations
alongside text, highlights, ink, etc.
