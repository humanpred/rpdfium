# Name- and point-based lookups against the document / page.
# Each is a thin wrapper around a single PDFium helper:
#
#   pdf_named_dest_by_name(doc, name)   - resolve a /Dest by name
#   pdf_bookmark_find(doc, title)       - find a bookmark by title
#   pdf_form_field_at_point(page, x, y) - form-field hit-test

#' Resolve a named destination by name
#'
#' Looks up a `/Dest` by its name string and returns the same kind
#' of row [pdf_named_dests()] surfaces — page, view, x, y, zoom.
#' Useful for following cross-document references such as
#' `RemoteGoTo` actions that carry a destination name rather than
#' a page index.
#'
#' Wraps `FPDF_GetNamedDestByName` plus `FPDFDest_GetDestPageIndex`
#' / `FPDFDest_GetView` / `FPDFDest_GetLocationInPage`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param name Single non-empty character string.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A list with `found` (logical), `page` (integer, 1-based,
#'   `NA` when not resolvable), and `dest_view` / `dest_x` /
#'   `dest_y` / `dest_zoom` (same shape as the corresponding
#'   columns on [pdf_named_dests()]). `found = FALSE` and all
#'   other fields `NA` when the name is not in the destination
#'   table.
#' @seealso [pdf_named_dests()].
#' @export
pdf_named_dest_by_name <- function(doc, name, password = NULL) {
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
        !nzchar(name)) {
    stop("`name` must be a single non-empty character string.",
         call. = FALSE)
  }
  h <- as_doc_handle(doc, "doc", password = password)
  on.exit(h$on_exit(), add = TRUE)
  raw <- cpp_named_dest_by_name(h$doc$ptr, enc2utf8(name))
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
#' Returns the 1-based `bookmark_index` of the first outline entry
#' matching `title`, suitable for indexing back into
#' [pdf_bookmarks()]'s tibble. `NA` when no bookmark matches.
#' Wraps `FPDFBookmark_Find` and walks the outline pre-order to map
#' the PDFium handle back to the row index.
#'
#' PDFium's matching is case-sensitive and matches the full title
#' string.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param title Single non-empty character string.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return Integer scalar — the 1-based bookmark_index, or `NA`.
#' @seealso [pdf_bookmarks()].
#' @export
pdf_bookmark_find <- function(doc, title, password = NULL) {
  if (!is.character(title) || length(title) != 1L || is.na(title) ||
        !nzchar(title)) {
    stop("`title` must be a single non-empty character string.",
         call. = FALSE)
  }
  h <- as_doc_handle(doc, "doc", password = password)
  on.exit(h$on_exit(), add = TRUE)
  idx <- cpp_bookmark_find(h$doc$ptr, enc2utf8(title))
  if (idx < 0L) NA_integer_ else as.integer(idx)
}

#' Form-field hit-test for a point
#'
#' Companion to [pdf_link_at_point()]: returns the form-field type
#' under `(x, y)` on `page`, plus its z-order. Useful for "what
#' would clicking here interact with?" workflows. Wraps
#' `FPDFPage_HasFormFieldAtPoint` and
#' `FPDFPage_FormFieldZOrderAtPoint`.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
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
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    stop("`x` must be a single finite numeric.", call. = FALSE)
  }
  if (!is.numeric(y) || length(y) != 1L || !is.finite(y)) {
    stop("`y` must be a single finite numeric.", call. = FALSE)
  }
  ph <- as_open_page_pair(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  raw <- cpp_form_field_at_point(ph$page$doc$ptr, ph$page$ptr,
                                  as.numeric(x), as.numeric(y))
  ftype <- as.integer(raw$field_type)
  type_name <- if (is.na(ftype)) NA_character_ else
    form_field_type_name(ftype)
  list(
    field_type = type_name,
    z_order    = as.integer(raw$z_order)
  )
}
