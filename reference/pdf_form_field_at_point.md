# Form-field hit-test for a point

Companion to
[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md):
returns the form-field type under `(x, y)` on `page`, plus its z-order.
Useful for "what would clicking here interact with?" workflows. Wraps
`FPDFPage_HasFormFieldAtPoint` and `FPDFPage_FormFieldZOrderAtPoint`.

## Usage

``` r
pdf_form_field_at_point(page, x, y, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc`.

- x, y:

  Point coordinates in PDF user-space points.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A list with two scalars:

- `field_type` character — `"textfield"`, `"checkbox"`, `"radiobutton"`,
  `"combobox"`, `"listbox"`, `"pushbutton"`, `"signature"`, one of the
  XFA variants, `"unknown"`, or `NA` when no form field is under the
  point.

- `z_order` integer — the form widget's z-order on the page (higher = on
  top); `NA` when no field is under the point.

## See also

[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md),
[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md).
