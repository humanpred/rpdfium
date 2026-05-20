# Generic annotation dict probing, appearance streams, link <-> annot
# bridges, and a direct marked-content ID accessor on page objects.
#
# These un-defer the v0.1.0 Tier 3 items that didn't fit existing
# modules: parallel structures to the attachment-dict / form-field
# probes already shipped.

# PDF appearance modes for FPDFAnnot_GetAP. Codes are 0/1/2
# (FPDF_ANNOT_APPEARANCEMODE_NORMAL/ROLLOVER/DOWN).
.pdfium_annot_appearance_modes <- c(
  normal   = 0L,
  rollover = 1L,
  down     = 2L
)

#' Read an annotation-dict entry by key
#'
#' Parallel to [pdf_attachment_dict_value()] but for annotations.
#' Returns the typed value of a key in the annotation's
#' dictionary — useful for ad-hoc access to keys [pdf_annotations()]
#' doesn't surface (e.g. `/M` modification date, `/NM` unique name,
#' `/CA` overall opacity, `/RC` rich-text contents).
#'
#' Wraps `FPDFAnnot_HasKey`, `FPDFAnnot_GetValueType`,
#' `FPDFAnnot_GetStringValue`, and `FPDFAnnot_GetNumberValue`. Only
#' string-, name-, and number-typed values come back; other
#' value types (dict / array / stream / reference) report
#' `value_type` accordingly but leave the typed accessors as `NA`.
#'
#' @param page A `pdfium_page` from [pdf_page_load()], or a
#'   `pdfium_doc`.
#' @param annotation_index One-based index into the page's
#'   annotations.
#' @param key The annotation-dict key as a single non-empty
#'   character string (ASCII PDF name, e.g. `"M"`, `"NM"`, `"CA"`).
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A list with four fields:
#'   * `has_key` (logical) — `TRUE` when the annotation dict
#'     contains `key`.
#'   * `value_type` (integer) — PDFium's `FPDF_OBJECT_*` enum
#'     value (`0`=unknown, `1`=boolean, `2`=number, `3`=string,
#'     `4`=name, ...); `NA` when the key is absent.
#'   * `value_string` (character) — populated when the value is a
#'     PDF string or name; `NA_character_` otherwise.
#'   * `value_number` (numeric) — populated when the value is a
#'     PDF number; `NA_real_` otherwise.
#' @seealso [pdf_annotations()] for the structured per-annotation
#'   readout, [pdf_annot_appearance()] for the `/AP` appearance
#'   stream.
#' @export
pdf_annot_dict_value <- function(page, annotation_index, key,
                                 page_num = 1L) {
  checkmate::assert_count(annotation_index, positive = TRUE)
  key <- assert_pdf_key(key)
  page <- as_open_page(page, page_num)
  raw <- cpp_annot_dict_value(
    page$ptr,
    as.integer(annotation_index - 1L),
    key
  )
  vs <- as.character(raw$value_string)
  # nocov start — defensive: cpp always returns a length-1 chr.
  if (length(vs) == 0L) vs <- NA_character_
  # nocov end
  list(
    has_key      = as.logical(raw$has_key),
    value_type   = as.integer(raw$value_type),
    value_string = vs[[1L]],
    value_number = as.numeric(raw$value_number)
  )
}

#' Appearance-stream string for an annotation
#'
#' Returns the contents of an annotation's `/AP` appearance stream
#' for the requested appearance mode. PDF annotations can carry up
#' to three appearance streams: `"normal"` (default, drawn at
#' rest), `"rollover"` (drawn while the cursor hovers), and
#' `"down"` (drawn while the annotation is being activated).
#' Wraps `FPDFAnnot_GetAP`.
#'
#' Useful for analysing or rebuilding custom annotations whose
#' appearance can't be reconstructed from the structural metadata
#' [pdf_annotations()] surfaces (color / border / quad points).
#'
#' @inheritParams pdf_annot_dict_value
#' @param mode One of `"normal"` (default), `"rollover"`, or
#'   `"down"`.
#' @return Character scalar — the appearance-stream content, or
#'   `""` when no appearance is set for the requested mode.
#' @seealso [pdf_annotations()], [pdf_annot_dict_value()].
#' @export
pdf_annot_appearance <- function(page, annotation_index,
                                 mode = c(
                                   "normal", "rollover",
                                   "down"
                                 ),
                                 page_num = 1L) {
  mode <- match.arg(mode)
  checkmate::assert_count(annotation_index, positive = TRUE)
  page <- as_open_page(page, page_num)
  code <- .pdfium_annot_appearance_modes[[mode]]
  as.character(cpp_annot_appearance(
    page$ptr,
    as.integer(annotation_index - 1L),
    as.integer(code)
  ))
}

#' Hit-test for a link annotation, returning its annotation index
#'
#' Companion to [pdf_link_at_point()] (which surfaces the link's
#' action / destination / URI) — this one returns the
#' page-scoped annotation index of the underlying link annotation
#' so the caller can hand it to [pdf_annot_dict_value()] /
#' [pdf_annot_appearance()] / [pdf_annotations()] for the full
#' structural readout. Wraps `FPDFLink_GetLinkAtPoint` +
#' `FPDFLink_GetAnnot`.
#'
#' @inheritParams pdf_link_at_point
#' @return A list with three fields:
#'   * `found` (logical) — `TRUE` when a link is under the point.
#'   * `annotation_index` (integer) — 1-based same-page annotation
#'     index of the underlying link annotation; `NA` when no link
#'     is found.
#'   * `z_order` (integer) — the link's Z-order on the page;
#'     `NA` when no link is found.
#' @seealso [pdf_link_at_point()], [pdf_annotations()].
#' @export
pdf_link_annot_at_point <- function(page, x, y, page_num = 1L) {
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  page <- as_open_page(page, page_num)
  raw <- cpp_link_annot_at_point(
    page$ptr,
    as.numeric(x), as.numeric(y)
  )
  list(
    found            = as.logical(raw$found),
    annotation_index = as.integer(raw$annotation_index),
    z_order          = as.integer(raw$z_order)
  )
}

#' Direct marked-content ID for a page object
#'
#' Fast-path single-integer accessor that wraps
#' `FPDFPageObj_GetMarkedContentID`. Equivalent to taking
#' [pdf_obj_marks()] and pulling out the first integer `MCID`
#' parameter, but avoids the tibble materialisation when the
#' caller only needs the ID.
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()].
#' @return Integer scalar — the 0-based marked-content ID, or
#'   `NA_integer_` when the object has no direct MCID.
#' @seealso [pdf_obj_marks()], [pdf_structure_tree()].
#' @export
pdf_obj_marked_content_id <- function(obj) {
  check_pdfium_obj(obj)
  mcid <- cpp_obj_marked_content_id(obj$ptr)
  if (mcid < 0L) NA_integer_ else as.integer(mcid)
}

#' Annotation subtypes registered as keyboard-focusable
#'
#' Returns the set of `FPDF_ANNOT_*` subtype codes the document's
#' form-fill module accepts for tab-focus, as names. Widget
#' annotations are always focusable by default; other subtypes can
#' be registered via `FPDFAnnot_SetFocusableSubtypes` (writer side,
#' not yet exposed). Wraps `FPDFAnnot_GetFocusableSubtypesCount`
#' and `FPDFAnnot_GetFocusableSubtypes`.
#'
#' Mostly a viewer-UI concern; exposed here for round-trip
#' completeness against the v0.2.0 setter.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return Character vector of annotation-subtype names. Empty when
#'   the document has no form-fill module or no focusable subtypes.
#' @seealso [pdf_annotations()] (`subtype` column maps to the same
#'   names).
#' @export
pdf_doc_focusable_subtypes <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  codes <- cpp_doc_focusable_subtypes(doc$ptr)
  annotation_subtype_name(codes)
}
