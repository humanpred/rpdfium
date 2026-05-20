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
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character
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
  # Don't defer-close the transient doc — the returned form-field
  # list pins the doc on its `source` attribute. R's GC handles
  # the close when the list itself is collected.
  doc <- as_open_doc(doc, defer_close = FALSE)
  raw <- cpp_form_field_handles(doc$ptr)
  # Build pdfium_page wrappers for every kept page; the externalptrs
  # have their own finalizers so each page closes via R's GC when
  # the form-field list is reclaimed.
  page_handles <- raw$page_handles
  page_nums <- as.integer(raw$page_nums)
  pages_used <- lapply(seq_along(page_handles), function(i) {
    new_pdfium_page(page_handles[[i]], doc, page_nums[i])
  })
  # Build pdfium_form_field handles, one per widget annot.
  annot_page_idx <- as.integer(raw$annot_page_idx)
  field_types <- as.integer(raw$field_types)
  fields <- lapply(seq_along(raw$annot_handles), function(i) {
    new_pdfium_form_field(
      ptr = raw$annot_handles[[i]],
      page = pages_used[[annot_page_idx[i]]],
      field_index = i,
      page_num = page_nums[annot_page_idx[i]],
      field_type_code = field_types[i]
    )
  })
  new_pdfium_form_field_list(fields, doc, pages_used)
}

#' Tibble view of a `pdfium_form_field_list`
#'
#' Walks the list of field handles and reads every documented
#' AcroForm property into a wide tibble. Adds two list-columns
#' relative to a simple data extraction: `handle` (the
#' `pdfium_form_field` per row) and `source` (the parent
#' `pdfium_doc`).
#'
#' Internally calls the existing bulk reader (`cpp_form_fields_list`)
#' for speed; per-row handles are pulled from the list itself so
#' R-object identity survives round-trip.
#'
#' @param x A `pdfium_form_field_list` from [pdf_form_fields()].
#' @param ... Unused (S3 generic compatibility).
#' @return A tibble matching the previous `pdf_form_fields()`
#'   shape plus `handle` + `source` columns.
#' @importFrom tibble as_tibble
#' @method as_tibble pdfium_form_field_list
#' @export
as_tibble.pdfium_form_field_list <- function(x, ...) {
  src_doc <- attr(x, "source")
  if (length(x) == 0L) {
    return(empty_form_field_tibble(src_doc))
  }
  raw <- cpp_form_fields_list(src_doc$ptr)
  type_name <- form_field_type_name(raw$field_type)
  field_flags <- as.integer(raw$field_flags)
  is_checked <- as.integer(raw$is_checked)
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
    additional_actions_js = raw$additional_actions_js,
    handle = unclass(x),
    source = rep(list(src_doc), length(x))
  )
}

# Internal: zero-row tibble matching as_tibble.pdfium_form_field_list.
empty_form_field_tibble <- function(src_doc) {
  tibble::tibble(
    field_index = integer(),
    page_num = integer(),
    field_type = character(),
    field_flags = integer(),
    is_readonly = logical(),
    is_required = logical(),
    is_no_export = logical(),
    is_checked = logical(),
    control_count = integer(),
    control_index = integer(),
    name = character(),
    alternate_name = character(),
    value = character(),
    export_value = character(),
    bounds_left = numeric(),
    bounds_bottom = numeric(),
    bounds_right = numeric(),
    bounds_top = numeric(),
    options = list(),
    is_option_selected = list(),
    additional_actions_js = list(),
    handle = list(),
    source = list()
  )
}

#' Coerce input to a `pdfium_form_field_list`
#'
#' Reverse companion to [as_tibble.pdfium_form_field_list()].
#'
#' @param x Either a `pdfium_form_field_list`, a plain list of
#'   `pdfium_form_field` handles, or a tibble with a `handle`
#'   list-column.
#' @return A `pdfium_form_field_list`.
#' @export
as_pdfium_form_field_list <- function(x) {
  if (inherits(x, "pdfium_form_field_list")) return(x)
  if (is.list(x) && length(x) > 0L &&
      all(vapply(x, inherits, logical(1L), "pdfium_form_field"))) {
    src_doc <- x[[1L]]$page$doc
    pages_used <- unique(lapply(x, function(f) f$page))
    return(new_pdfium_form_field_list(x, src_doc, pages_used))
  }
  if (tibble::is_tibble(x) && "handle" %in% names(x)) {
    handles <- x$handle
    if (length(handles) == 0L) {
      stop("Cannot rebuild a `pdfium_form_field_list` from a zero-",
           "row tibble (source doc unknown).", call. = FALSE)
    }
    src_doc <- x$source[[1L]]
    pages_used <- unique(lapply(handles, function(f) f$page))
    return(new_pdfium_form_field_list(handles, src_doc, pages_used))
  }
  stop("`x` must be a `pdfium_form_field_list`, a list of ",
       "`pdfium_form_field`, or a tibble produced by ",
       "`as_tibble(pdf_form_fields(doc))`.", call. = FALSE)
}

#' Form-field type (string)
#'
#' Returns the AcroForm field type as a short name. Wraps
#' `FPDFAnnot_GetFormFieldType`.
#'
#' @param field A `pdfium_form_field` handle from
#'   [pdf_form_fields()].
#' @return Character scalar; one of `"unknown"`, `"pushbutton"`,
#'   `"checkbox"`, `"radiobutton"`, `"combobox"`, `"listbox"`,
#'   `"text"`, `"signature"`.
#' @export
pdf_form_field_type <- function(field) {
  checkmate::assert_class(field, "pdfium_form_field")
  if (!is_open(field)) {
    stop("Form-field handle has been closed.", call. = FALSE)
  }
  form_field_type_name(field$field_type_code)
}

#' Form-field type code (integer enum)
#'
#' Returns the raw `FPDF_FORMFIELD_*` integer.
#'
#' @inheritParams pdf_form_field_type
#' @return Integer scalar.
#' @export
pdf_form_field_type_code <- function(field) {
  checkmate::assert_class(field, "pdfium_form_field")
  field$field_type_code
}

#' Form-field page number
#'
#' Returns the 1-based index of the page carrying this field.
#'
#' @inheritParams pdf_form_field_type
#' @return Integer scalar.
#' @export
pdf_form_field_page_num <- function(field) {
  checkmate::assert_class(field, "pdfium_form_field")
  field$page_num
}

# Internal: PDFium field-type code -> name, vectorized.
form_field_type_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_form_field_types)
}
