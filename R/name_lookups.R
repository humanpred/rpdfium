# Name- and point-based lookups against the document / page.
# Each is a thin wrapper around a single PDFium helper:
#
#   pdf_doc_named_dest_by_name(doc, name)   - resolve a /Dest by name
#   pdf_doc_bookmark_find(doc, title)       - find a bookmark by title
#   pdf_form_field_at_point(page, x, y) - form-field hit-test

#' Resolve a named destination by name
#'
#' Looks up a `/Dest` by its name string and returns the same kind
#' of row [pdf_doc_named_dests()] surfaces — page, view, x, y, zoom.
#' Useful for following cross-document references such as
#' `RemoteGoTo` actions that carry a destination name rather than
#' a page index.
#'
#' Wraps `FPDF_GetNamedDestByName` plus `FPDFDest_GetDestPageIndex`
#' / `FPDFDest_GetView` / `FPDFDest_GetLocationInPage`.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @param name Single non-empty character string.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A list with `found` (logical), `page` (integer, 1-based,
#'   `NA` when not resolvable), and `dest_view` / `dest_x` /
#'   `dest_y` / `dest_zoom` (same shape as the corresponding
#'   columns on [pdf_doc_named_dests()]). `found = FALSE` and all
#'   other fields `NA` when the name is not in the destination
#'   table.
#' @seealso [pdf_doc_named_dests()].
#' @export
pdf_doc_named_dest_by_name <- function(doc, name, password = NULL) {
  name <- assert_pdf_key(name, arg = "name")
  doc <- as_open_doc(doc, password = password)
  raw <- cpp_named_dest_by_name(doc$ptr, name)
  list(
    found     = as.logical(raw$found),
    page      = as.integer(raw$page),
    dest_view = pdfium_dest_view_name(raw$dest_view),
    dest_x    = as.numeric(raw$dest_x),
    dest_y    = as.numeric(raw$dest_y),
    dest_zoom = as.numeric(raw$dest_zoom)
  )
}

#' Find a bookmark by its title
#'
#' Returns the matching `pdfium_bookmark` handle, or `NULL` when no
#' outline entry matches `title`. The returned handle is usable with
#' every per-attribute getter ([pdf_bookmark_title()],
#' [pdf_bookmark_page_num()], ...) and can be slotted back into
#' [as_pdfium_bookmark_list()] with other handles. Wraps
#' `FPDFBookmark_Find` plus a pre-order walk to recover the
#' structural `index` / `parent_index` / `level` fields.
#'
#' PDFium's matching is case-sensitive and matches the full title
#' string.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @param title Single non-empty character string.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A `pdfium_bookmark` handle, or `NULL` when no match.
#' @seealso [pdf_doc_bookmarks()], [pdf_bookmark_title()].
#' @export
pdf_doc_bookmark_find <- function(doc, title, password = NULL) {
  title <- assert_pdf_key(title, arg = "title")
  doc <- as_open_doc(doc, password = password, defer_close = FALSE)
  raw <- cpp_bookmark_find_handle(doc$ptr, title)
  if (!isTRUE(raw$found)) return(NULL)
  new_pdfium_bookmark(
    raw$handle, doc,
    index        = raw$index,
    parent_index = raw$parent_index,
    level        = raw$level
  )
}

#' Form-field hit-test for a point
#'
#' Companion to [pdf_link_at_point()]: returns the form-field type
#' under `(x, y)` on `page`, plus its z-order. Useful for "what
#' would clicking here interact with?" workflows. Wraps
#' `FPDFPage_HasFormFieldAtPoint` and
#' `FPDFPage_FormFieldZOrderAtPoint`.
#'
#' @param page A `pdfium_page` from [pdf_page_load()], or a
#'   `pdfium_doc`.
#' @param x,y Point coordinates in PDF user-space points.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A list with two scalars:
#'   * `field_type` character — `"textfield"`, `"checkbox"`,
#'     `"radiobutton"`, `"combobox"`, `"listbox"`, `"pushbutton"`,
#'     `"signature"`, one of the XFA variants, `"unknown"`, or
#'     `NA` when no form field is under the point.
#'   * `z_order` integer — the form widget's z-order on the page
#'     (higher = on top); `NA` when no field is under the point.
#' @seealso [pdf_form_fields()], [pdf_link_at_point()].
#' @export
pdf_form_field_at_point <- function(page, x, y, page_num = 1L) {
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  page <- as_open_page(page, page_num)
  raw <- cpp_form_field_at_point(
    page$doc$ptr, page$ptr,
    as.numeric(x), as.numeric(y)
  )
  ftype <- as.integer(raw$field_type)
  type_name <- if (is.na(ftype)) {
    NA_character_
  } else {
    form_field_type_name(ftype)
  }
  list(
    field_type = type_name,
    z_order    = as.integer(raw$z_order)
  )
}
