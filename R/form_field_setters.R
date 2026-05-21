# Form-field writers (Phase 7 of the v0.1.0 writer surface).
#
# Four exports:
#   pdf_form_field_set_value(field, value)   per-field, polymorphic
#   pdf_form_field_clear(field)              per-field, /V -> /DV
#   pdf_form_reset(doc)                      doc-wide clear all
#   pdf_page_flatten(page, mode)             bake forms + annots
#                                              into the page stream
#
# `pdf_form_field_set_value` dispatches by the field's type code:
#   * text fields           character scalar -> /V
#   * checkbox / radio      logical scalar  -> on-state name or /Off
#                           OR character     -> literal /V (e.g.
#                                                pre-known export
#                                                value)
#   * combobox / listbox    character scalar -> matched against the
#                                                field's /Opt list
#
# All setters use FPDFAnnot_SetStringValue on the widget annot
# dict to write /V. PDFium's appearance stream regeneration
# happens on render / save via the existing per-annot AP-dirty
# flag; we explicitly call cpp_annot_touch_ap after each /V change
# so the flag flips even when PDFium's internal SetStringValue
# doesn't do it for us.
#
# `/Opt` array writing is intentionally not exposed — PDFium has
# no public API for it. See dev/upstream-patches/ for the upstream
# request.

# Flatten mode codes from fpdf_flatten.h.
.pdfium_flatten_modes <- c(display = 0L, print = 1L)
# FPDFPage_Flatten return codes.
.pdfium_flatten_returns <- c(failed = 0L, success = 1L,
                              nothing_to_do = 2L)

# Internal: validate that `field` is an open pdfium_form_field
# whose parent doc is readwrite. Returns the parent doc + page
# index for finalize_obj_setter() to mark dirty.
assert_form_field_writable <- function(field, arg = "field") {
  check_form_field(field, arg = arg)
  doc <- field$page$doc
  assert_readwrite(doc)
  list(doc = doc, page_index = field$page$index)
}

# Internal: write /V on a widget annot, then flip the AP-dirty
# flag so the next render/save regenerates the appearance.
write_form_value <- function(field, value_chr) {
  expect_setter_ok(
    cpp_annot_set_string_value(field$ptr, "V",
                                 enc2utf8(value_chr)),
    "FPDFAnnot_SetStringValue(V)"
  )
  expect_setter_ok(cpp_annot_touch_ap(field$ptr),
                    "FPDFAnnot_SetRect (AP-dirty flag)")
}

# Internal: which field-type codes count as checkable
# (checkbox / radio / XFA-checkbox).
.pdfium_checkable_codes <- c(2L, 3L, 9L)

# Internal: which field-type codes are choice fields
# (combobox / listbox / XFA-listbox / XFA-combobox).
.pdfium_choice_codes <- c(4L, 5L, 10L, 12L)

# Internal: text-style codes (textfield / XFA-text).
.pdfium_text_codes <- c(6L, 15L)

# Internal: PDFium's checkbox / radio "on-state name" is the only
# /AP/N key that isn't /Off. Reading via FPDFAnnot_GetStringValue
# at "AS" gives the current state; reading the /AP dict gives the
# possible on-state name. We don't have a public API for the
# latter, so we fall back to the field's currently-non-Off /V if
# present, else "Yes" (the de-facto convention).
infer_on_state_name <- function(field) {
  current <- cpp_annot_string_value(field$ptr, "V")
  if (nzchar(current) && current != "Off") {
    return(current)
  }
  # nocov start — the /V-first path always wins on the shipped
  # checkbox fixture (its /V is "Yes" or "Off", never absent).
  # /AS fallback handles checkboxes whose /V is missing and
  # rely on the /AS appearance state to encode the on-state name.
  current_as <- cpp_annot_string_value(field$ptr, "AS")
  if (nzchar(current_as) && current_as != "Off") {
    return(current_as)
  }
  "Yes"
  # nocov end
}

#' Set the value of a form field
#'
#' Polymorphic setter: the semantics depend on the field's type.
#'
#' * **Text** (`"textfield"`, `"xfa_textfield"`): `value` must be a
#'   character scalar. Sets `/V` directly.
#' * **Checkbox / radio** (`"checkbox"`, `"radiobutton"`,
#'   `"xfa_checkbox"`): `value` may be either a logical scalar or a
#'   character scalar. `TRUE` writes the field's on-state name
#'   (inferred from the current `/V` or `/AS`, falling back to
#'   `"Yes"`); `FALSE` writes `"Off"`. A character value is written
#'   literally — useful when you already know the export-value
#'   string and want to bypass inference.
#' * **Combobox / listbox** (`"combobox"`, `"listbox"`,
#'   `"xfa_combobox"`, `"xfa_listbox"`): `value` must be a character
#'   scalar matching one of the field's options
#'   ([pdf_form_field_options()]).
#'
#' Any other field type (button / signature / unknown) errors —
#' those don't have a settable value.
#'
#' Wraps `FPDFAnnot_SetStringValue(annot, "V", ...)` followed by a
#' rect re-touch (`FPDFAnnot_SetRect` to the current rect) that
#' flips the AP-dirty flag, so the next [pdf_render_page()] or
#' [pdf_save()] rebuilds the widget's appearance stream from the
#' new value.
#'
#' @param field A `pdfium_form_field` from [pdf_form_fields()].
#'   Parent doc must be readwrite.
#' @param value Character scalar OR logical scalar (for checkable
#'   types). See type-specific rules above.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_form_field_value()], [pdf_form_field_clear()],
#'   [pdf_form_reset()].
#' @export
pdf_form_field_set_value <- function(field, value) {
  ctx <- assert_form_field_writable(field)
  type <- field$field_type_code
  if (type %in% .pdfium_text_codes) {
    checkmate::assert_string(value, na.ok = FALSE)
    write_form_value(field, value)
  } else if (type %in% .pdfium_checkable_codes) {
    if (is.logical(value)) {
      checkmate::assert_flag(value)
      v <- if (value) infer_on_state_name(field) else "Off"
    } else {
      checkmate::assert_string(value, na.ok = FALSE)
      v <- value
    }
    write_form_value(field, v)
    # Mirror /V into /AS so the appearance state matches the value.
    # /AS is what PDFium reads when choosing the AP/N entry.
    expect_setter_ok(
      cpp_annot_set_string_value(field$ptr, "AS", enc2utf8(v)),
      "FPDFAnnot_SetStringValue(AS)"
    )
  } else if (type %in% .pdfium_choice_codes) {
    # nocov start — shipped fixtures have no combobox / listbox.
    # The choice branch is exercised by the upstream conformance
    # suite (kmextract repo) but isn't reproducible from the
    # in-repo fixtures alone. Building a choice-field PDF needs
    # FPDFAnnot_SetStringValue("Opt", ...) which PDFium doesn't
    # expose — see dev/upstream-patches/.
    checkmate::assert_string(value, na.ok = FALSE)
    options_list <- pdf_form_field_options(field)
    if (length(options_list) > 0L && !value %in% options_list) {
      stop(sprintf(
        "`value` (%s) is not one of this field's options: %s",
        shQuote(value),
        paste(shQuote(options_list), collapse = ", ")
      ), call. = FALSE)
    }
    write_form_value(field, value)
    # nocov end
  } else {
    stop(sprintf(
      "Field type %s does not have a settable value.",
      shQuote(form_field_type_name(type))
    ), call. = FALSE)
  }
  finalize_obj_setter(ctx)
}

#' Clear a form field to its default value
#'
#' Restores `/V` to the field's `/DV` entry (the dictionary's
#' "default value"). If `/DV` is absent, writes the type-
#' appropriate empty:
#'
#' * Text / choice: empty string.
#' * Checkbox / radio: `"Off"` and mirrors `/AS` to match.
#'
#' Wraps `FPDFAnnot_GetStringValue(annot, "DV", ...)` +
#' [pdf_form_field_set_value()].
#'
#' @inheritParams pdf_form_field_set_value
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_form_reset()] for the doc-wide variant.
#' @export
pdf_form_field_clear <- function(field) {
  assert_form_field_writable(field)
  default <- cpp_annot_string_value(field$ptr, "DV")
  type <- field$field_type_code
  if (nzchar(default)) {
    pdf_form_field_set_value(field, default)  # nocov
  } else if (type %in% .pdfium_checkable_codes) {
    pdf_form_field_set_value(field, FALSE)
  } else {
    pdf_form_field_set_value(field, "")
  }
}

#' Reset every form field in the document to its default value
#'
#' Convenience wrapper that calls [pdf_form_field_clear()] on
#' every form field in `doc`. PDFium has no public `FORM_Reset`
#' symbol, so this is implemented as a loop over the field list.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()]. Must be
#'   readwrite.
#' @return Invisibly returns `doc`.
#' @seealso [pdf_form_field_clear()].
#' @export
pdf_form_reset <- function(doc) {
  assert_readwrite(doc)
  fields <- pdf_form_fields(doc)
  for (f in fields) pdf_form_field_clear(f)
  invisible(doc)
}

#' Flatten form fields and annotations into the page content stream
#'
#' Wraps `FPDFPage_Flatten`. After flattening, form widgets and
#' annotations are baked into the page's content stream as static
#' graphics — they no longer exist as interactive objects. **This
#' is irreversible**: there is no `pdf_page_unflatten()`. Use this
#' before saving a final-state PDF that downstream consumers must
#' not edit.
#'
#' Two modes:
#' * `"display"` (default) — bake the on-screen appearance of every
#'   annot / widget.
#' * `"print"` — bake the print-time appearance instead.
#'
#' Returns the page invisibly. The parent page's dirty mark is set
#' so [pdf_save()] picks up the change.
#'
#' @param page A `pdfium_page` from [pdf_page_load()]. Parent doc
#'   must be readwrite.
#' @param mode Character scalar; one of `"display"` or `"print"`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_save()].
#' @export
pdf_page_flatten <- function(page, mode = c("display", "print")) {
  mode <- match.arg(mode)
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  mode_code <- .pdfium_flatten_modes[[mode]]
  rc <- cpp_page_flatten(ph$page$ptr, mode_code)
  if (rc == .pdfium_flatten_returns[["failed"]]) {
    stop("FPDFPage_Flatten failed.", call. = FALSE)  # nocov
  }
  # rc 1 (success) and 2 (nothing-to-do) both count as OK. The
  # nothing-to-do path is valid — a page with no annots / widgets
  # is already flat.
  mark_page_dirty(ph$doc, ph$page$index)
  invisible(ph$doc)
}
