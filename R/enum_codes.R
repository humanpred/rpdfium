# Bidirectional enum-code helpers (Phase 9).
#
# Six PDFium enums surface in user-visible columns of one or more
# pdf_*() tibbles:
#
#   * annot subtype           - pdf_annot_subtype()
#   * page-object type        - pdf_obj_type()
#   * path-segment type       - pdf_path_segments()$segment_type
#   * form-field type         - pdf_form_field_type()
#   * link / page-action type - pdf_link_at_point()$action_type
#   * named-destination view  - pdf_bookmark_dest_view()
#
# Each one has a code <-> name mapping table living next to the
# function that ships the name column (`.pdfium_*_names` /
# `.pdfium_*_types` / `.pdfium_*_views`). The forward conversions
# (code -> name) are used internally by every reader to fill the
# tibble. The inverse direction (name -> code) is what users need
# when:
#
#   * filtering a tibble by code (e.g. `obj_type_code == 3L` to keep
#     image objects);
#   * passing a code into a downstream setter (e.g.
#     `pdf_annot_new(page, subtype = ...)` takes a name string, but
#     the code is what PDFium speaks);
#   * round-tripping through a saved CSV that lost the names but
#     kept the codes.
#
# Phase 9 exposes both directions as paired user-facing exports so
# the code/name space is symmetric and discoverable. The forward
# direction reuses the shared `.pdfium_enum_name()` helper in
# R/utils.R; the inverse direction has its own private helper here
# (kept colocated to avoid cross-file static-analysis noise).

# Internal: inverse of `.pdfium_enum_name`. Maps a character vector
# of enum names (case-insensitive) back to integer codes. `base` is
# the integer code of `names[1]` — match the value passed to the
# matching `.pdfium_enum_name()` call. Unknown / NA inputs collapse
# to `fallback` (default 0L — every PDFium enum reserves 0 for
# UNKNOWN). Vectorized; returns an `integer` of the same length as
# `x`.
.pdfium_enum_code <- function(x, names, base = 0L, fallback = 0L) {
  hit <- match(tolower(as.character(x)), names)
  out <- ifelse(is.na(hit), fallback, hit - 1L + base)
  # ifelse(<empty>, ...) returns logical(0); force integer so a
  # zero-length input yields integer(0), matching the typed return
  # of every other enum-helper in the package.
  as.integer(out)
}

#' PDF annotation subtype codes <-> names
#'
#' PDFium reports the annotation subtype as an integer code in the
#' `FPDF_ANNOT_*` enum (0 = unknown, 1 = text, 2 = link, ...,
#' 28 = redact). `pdf_annotations()` already surfaces both `subtype`
#' (name) and `subtype_code` (integer). These helpers expose the
#' name<->code mapping as a standalone vectorized conversion.
#'
#' Names are case-insensitive on input; unknown names map to 0
#' (`unknown`). Out-of-range codes map to `"unknown"`.
#'
#' @param codes Integer vector of PDFium subtype codes.
#' @param names Character vector of subtype names (case-insensitive).
#' @return A character vector (`_name()`) or integer vector
#'   (`_code()`), same length as the input.
#' @seealso [pdf_annotations()], [pdf_annot_subtype()],
#'   [pdf_annot_new()].
#' @examples
#' pdfium_annot_subtype_name(c(1L, 2L, 9L))
#' #> [1] "text" "link" "highlight"
#' pdfium_annot_subtype_code(c("text", "Link", "fileattachment"))
#' #> [1]  1  2 17
#' @export
pdfium_annot_subtype_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_annot_subtypes)
}

#' @rdname pdfium_annot_subtype_name
#' @export
pdfium_annot_subtype_code <- function(names) {
  .pdfium_enum_code(names, .pdfium_annot_subtypes)
}

#' PDF page-object type codes <-> names
#'
#' PDFium reports the type of each page object as an integer code
#' (0 = unknown, 1 = text, 2 = path, 3 = image, 4 = shading,
#' 5 = form XObject). `pdf_obj_type()` returns the name; this
#' helper exposes the symmetric direction.
#'
#' @inheritParams pdfium_annot_subtype_name
#' @return A character vector (`_name()`) or integer vector
#'   (`_code()`), same length as the input.
#' @seealso [pdf_obj_type()], [pdf_page_objects()].
#' @examples
#' pdfium_obj_type_name(c(1L, 2L, 3L))
#' #> [1] "text" "path" "image"
#' pdfium_obj_type_code(c("text", "Image", "form"))
#' #> [1] 1 3 5
#' @export
pdfium_obj_type_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_obj_type_names)
}

#' @rdname pdfium_obj_type_name
#' @export
pdfium_obj_type_code <- function(names) {
  .pdfium_enum_code(names, .pdfium_obj_type_names)
}

#' Path-segment type codes <-> names
#'
#' PDFium's `FPDFPathSegment_GetType` returns one of `0` (lineto),
#' `1` (bezierto), or `2` (moveto). `pdf_path_segments()` surfaces
#' the name as `segment_type`. These helpers expose the mapping for
#' programmatic filters / round-trips.
#'
#' @inheritParams pdfium_annot_subtype_name
#' @return A character vector (`_name()`) or integer vector
#'   (`_code()`), same length as the input.
#' @seealso [pdf_path_segments()].
#' @examples
#' pdfium_segment_type_name(c(0L, 1L, 2L))
#' #> [1] "lineto"  "bezierto" "moveto"
#' pdfium_segment_type_code(c("moveto", "lineto", "bezierto"))
#' #> [1] 2 0 1
#' @export
pdfium_segment_type_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_segment_type_names)
}

#' @rdname pdfium_segment_type_name
#' @export
pdfium_segment_type_code <- function(names) {
  .pdfium_enum_code(names, .pdfium_segment_type_names)
}

#' Form-field type codes <-> names
#'
#' Form-field types are reported by `FPDFAnnot_GetFormFieldType`
#' as `FPDF_FORMFIELD_*` codes (0 = unknown, 1 = pushbutton,
#' 2 = checkbox, 3 = radiobutton, 4 = combobox, 5 = listbox,
#' 6 = textfield, 7 = signature, 8 = xfa, and 9-15 for XFA-specific
#' flavors). [pdf_form_field_type()] returns the name; these
#' helpers expose the mapping.
#'
#' @inheritParams pdfium_annot_subtype_name
#' @return A character vector (`_name()`) or integer vector
#'   (`_code()`), same length as the input.
#' @seealso [pdf_form_field_type()], [pdf_form_fields()].
#' @examples
#' pdfium_form_field_type_name(c(2L, 6L, 4L))
#' #> [1] "checkbox" "textfield" "combobox"
#' pdfium_form_field_type_code(c("checkbox", "Textfield", "listbox"))
#' #> [1] 2 6 5
#' @export
pdfium_form_field_type_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_form_field_types)
}

#' @rdname pdfium_form_field_type_name
#' @export
pdfium_form_field_type_code <- function(names) {
  .pdfium_enum_code(names, .pdfium_form_field_types)
}

#' Link / page action type codes <-> names
#'
#' PDFium reports action types as `FPDFACTION_*` codes
#' (0 = unsupported, 1 = goto, 2 = remote_goto, 3 = uri,
#' 4 = launch, 5 = embedded_goto). [pdf_link_at_point()] and the
#' page-additional-actions API return the name as `action_type`;
#' these helpers expose the symmetric direction.
#'
#' Note: the `FPDFACTION_*` enum is 1-based (with 0 reserved for
#' "unsupported"), so the conversion respects that base.
#'
#' @inheritParams pdfium_annot_subtype_name
#' @return A character vector (`_name()`) or integer vector
#'   (`_code()`), same length as the input.
#' @seealso [pdf_link_at_point()], [pdf_page_actions()],
#'   [pdf_bookmark_action_type()].
#' @examples
#' pdfium_action_type_name(c(1L, 3L, 5L))
#' #> [1] "goto" "uri" "embedded_goto"
#' pdfium_action_type_code(c("goto", "URI", "launch"))
#' #> [1] 1 3 4
#' @export
pdfium_action_type_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_action_types,
                    base = 1L, fallback = "unsupported")
}

#' @rdname pdfium_action_type_name
#' @export
pdfium_action_type_code <- function(names) {
  .pdfium_enum_code(names, .pdfium_action_types,
                    base = 1L, fallback = 0L)
}

#' Named-destination view-mode codes <-> names
#'
#' Named-destination view modes are reported as `PDFDEST_VIEW_*`
#' codes (0 = unknown, 1 = xyz, 2 = fit, 3 = fith, 4 = fitv,
#' 5 = fitr, 6 = fitb, 7 = fitbh, 8 = fitbv).
#' [pdf_bookmark_dest_view()] returns the name; these helpers
#' expose the mapping.
#'
#' Note: like the action-type enum, this enum is 1-based (with 0
#' reserved for the unknown sentinel).
#'
#' @inheritParams pdfium_annot_subtype_name
#' @return A character vector (`_name()`) or integer vector
#'   (`_code()`), same length as the input.
#' @seealso [pdf_bookmark_dest_view()], [pdf_doc_named_dests()].
#' @examples
#' pdfium_dest_view_name(c(1L, 2L, 5L))
#' #> [1] "xyz" "fit" "fitr"
#' pdfium_dest_view_code(c("xyz", "Fit", "fitr"))
#' #> [1] 1 2 5
#' @export
pdfium_dest_view_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_dest_views, base = 1L)
}

#' @rdname pdfium_dest_view_name
#' @export
pdfium_dest_view_code <- function(names) {
  .pdfium_enum_code(names, .pdfium_dest_views, base = 1L)
}
