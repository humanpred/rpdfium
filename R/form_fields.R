# AcroForm field readout. PDF interactive form fields are
# implemented as FPDF_ANNOT_WIDGET-subtype annotations. They
# carry field-specific metadata (name, type, value, choice
# options) that PDFium only exposes through the FPDF_FORMHANDLE
# returned by FPDFDOC_InitFormFillEnvironment. This module wraps
# the init / enumerate / teardown lifecycle in a single call so
# users see a flat tibble per document.

# Internal: PDFium FPDF_FORMFIELD_* code -> human-readable name.
# See fpdf_formfill.h for the codes.
.pdfium_form_field_types <- c(
  "unknown", #  0 FPDF_FORMFIELD_UNKNOWN
  "pushbutton", #  1
  "checkbox", #  2
  "radiobutton", #  3
  "combobox", #  4
  "listbox", #  5
  "textfield", #  6
  "signature", #  7
  "xfa", #  8 (XFA-only flavours below; rare)
  "xfa_checkbox", #  9
  "xfa_combobox", # 10
  "xfa_imagefield", # 11
  "xfa_listbox", # 12
  "xfa_pushbutton", # 13
  "xfa_signature", # 14
  "xfa_textfield" # 15
)

# PDF spec Table 226 / 227: bit positions of the universal AcroForm
# field flags (the three apply to every field type). Type-specific
# bits like Password (textfield bit 13), Comb (textfield bit 24),
# or MultiSelect (listbox bit 22) are not decoded — callers wanting
# them can mask `field_flags` directly.
.pdfium_field_flag_bits <- c(
  is_readonly  = 1L,
  is_required  = 2L,
  is_no_export = 3L
)

# Internal: decode a bitmask (integer scalar) into a named logical
# vector using .pdfium_field_flag_bits. Vectorised over the bitmask.
form_field_flag_decode <- function(flags, bit) {
  bitwAnd(flags, bitwShiftL(1L, bit - 1L)) != 0L
}

#' Enumerate AcroForm fields across the whole document
#'
#' Returns one tibble row per form widget across every page of
#' the document. Walks each page's annotations, filters to those
#' of subtype `widget`, and reads PDFium's form-field metadata
#' through a transient `FPDF_FORMHANDLE` (init / enumerate /
#' teardown happens inside one call - the handle is not exposed
#' to R).
#'
#' Wraps `FPDFDOC_InitFormFillEnvironment`,
#' `FPDFDOC_ExitFormFillEnvironment`, the
#' `FPDFAnnot_GetFormField*` family, `FPDFAnnot_IsChecked` for the
#' check/radio state, and `FPDFAnnot_GetOption*` for choice-list
#' options.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character
#'   path.
#' @return A tibble with columns:
#'   * `field_index` integer - 1-based, document-wide ordering
#'     (page-major, then in-page annotation order).
#'   * `page_num` integer - 1-based page the widget lives on.
#'   * `field_type` character - one of `"pushbutton"`,
#'     `"checkbox"`, `"radiobutton"`, `"combobox"`,
#'     `"listbox"`, `"textfield"`, `"signature"`, or one of the
#'     XFA variants (`"xfa_*"`); `"unknown"` for non-AcroForm
#'     widgets PDFium can't classify.
#'   * `field_flags` integer - raw PDF form-field flags bitmask
#'     (bit 1 = ReadOnly, bit 2 = Required, bit 3 = NoExport,
#'     bit 13 = Password for textfields, bit 16 = MultiLine for
#'     textfields, etc.; see PDF spec Table 226).
#'   * `is_readonly`, `is_required`, `is_no_export` logical -
#'     decoded universal flag bits (bits 1, 2, 3) for convenience.
#'   * `is_checked` logical - current state of the widget;
#'     `TRUE` / `FALSE` for `checkbox` / `radiobutton` fields,
#'     `NA` for every other field type.
#'   * `control_count` integer - total number of widgets in this
#'     field's control group (≥ 1; `> 1` for radio button groups
#'     with multiple physical widgets). `NA` if PDFium reports
#'     failure.
#'   * `control_index` integer - 0-based position of this row's
#'     widget within its control group. For a checkbox or a
#'     standalone widget this is `0`. `NA` if PDFium reports
#'     failure.
#'   * `name` character - fully qualified field name, the
#'     period-joined dotted path PDFium reports (e.g.
#'     `"address.city"`).
#'   * `alternate_name` character - the field's user-facing
#'     label (the `/TU` entry), shown by viewers as a tooltip.
#'   * `value` character - the field's current display value.
#'     For text fields this is the entered text. For combo /
#'     listbox fields this is the *label* of the selected
#'     option (use `export_value` for the underlying export
#'     name). For checkbox / radio fields this is the
#'     appearance-state name ("Off" or the on-state name).
#'   * `export_value` character - the field's export value
#'     (`/V`). Same as `value` for text fields. For buttons,
#'     the value that gets submitted in form data (e.g. "Yes"
#'     for a checkbox, or the radio's on-state name).
#'   * `bounds_left`, `bounds_bottom`, `bounds_right`,
#'     `bounds_top` - widget rectangle in PDF user space.
#'   * `options` list-column of character vectors - the choice
#'     labels for `combobox` and `listbox` fields; empty
#'     character vector for other types.
#'   * `is_option_selected` list-column of logical vectors,
#'     one element per option (matches `options`). `TRUE` when
#'     the option is currently selected. Empty for non-choice
#'     fields.
#'   * `additional_actions_js` list-column of length-4 character
#'     vectors named `c("key_stroke", "format", "validate",
#'     "calculate")`. Each element is the JavaScript source
#'     string PDFium reports for the corresponding trigger
#'     event, or `""` when the trigger has no JS handler.
#'     Surfaced read-only here; v0.2.0 may expose a writer.
#'
#' Returns a 0-row tibble of the same schema when the document
#' has no AcroForm dictionary.
#'
#' @seealso [pdf_annotations()] for the page-level annotation
#'   surface that includes widget annotations alongside text,
#'   highlights, ink, etc.
#' @export
pdf_form_fields <- function(doc) {
  doc <- as_open_doc(doc)
  raw <- cpp_form_fields_list(doc$ptr)
  type_name <- form_field_type_name(raw$field_type)
  field_flags <- as.integer(raw$field_flags)
  is_checked <- as.integer(raw$is_checked)
  # cpp sends -1 for "not a checkable type"; map to NA logical.
  # For checkable types where FPDFAnnot_IsChecked returned false but
  # PDFium's reported `value` is the on-state name (i.e. anything
  # other than "Off" / empty), trust the value-side answer — this
  # closes a known PDFium quirk where the ControlMap lookup misses
  # for some hand-built PDFs.
  is_checked_lgl <- ifelse(is_checked < 0L, NA, is_checked != 0L)
  checkable <- !is.na(is_checked_lgl)
  inferred <- checkable & !is_checked_lgl &
    nzchar(raw$value) & raw$value != "Off"
  is_checked_lgl[inferred] <- TRUE
  decode <- function(bit_name) {
    form_field_flag_decode(
      field_flags,
      .pdfium_field_flag_bits[[bit_name]]
    )
  }
  tibble::tibble(
    field_index = seq_along(type_name),
    page_num = as.integer(raw$page_num),
    field_type = type_name,
    field_flags = field_flags,
    is_readonly = decode("is_readonly"),
    is_required = decode("is_required"),
    is_no_export = decode("is_no_export"),
    is_checked = is_checked_lgl,
    control_count = na_if_negative(raw$control_count),
    control_index = na_if_negative(raw$control_index),
    name = raw$name,
    alternate_name = raw$alternate_name,
    value = raw$value,
    export_value = raw$export_value,
    bounds_left = raw$bounds_left,
    bounds_bottom = raw$bounds_bottom,
    bounds_right = raw$bounds_right,
    bounds_top = raw$bounds_top,
    options = raw$options,
    is_option_selected = raw$is_option_selected,
    additional_actions_js = raw$additional_actions_js
  )
}

# Internal: PDFium field-type code -> name, vectorized.
form_field_type_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_form_field_types)
}
