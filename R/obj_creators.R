# Page-object creators (Phase 5 of the v0.1.0 writer surface).
#
# Each creator takes an open page (readwrite), creates a fresh
# FPDF_PAGEOBJECT on the C side, inserts it into the page in one
# shot (no detached-object R-side lifetime to manage), marks the
# parent page dirty, and returns the new `pdfium_obj` for the
# caller to either mutate further (Phase 3/4 setters) or chain
# into.
#
# pdf_obj_delete is the inverse: it removes the object from its
# parent page, destroys the C++ object, AND clears the
# externalptr so subsequent calls on the same handle error
# cleanly through the existing is_open() chain.

#' Create a new path page-object on a page
#'
#' Wraps `FPDFPageObj_CreateNewPath` + `FPDFPage_InsertObject`.
#' The new path starts with an implicit MoveTo at `(x, y)`; build
#' it up further with [pdf_path_line_to()] / [pdf_path_bezier_to()]
#' / [pdf_path_close()], then set styling via [pdf_path_set_stroke()]
#' / [pdf_path_set_fill()] / [pdf_path_set_draw_mode()].
#'
#' @param page A `pdfium_page` from [pdf_page_load()]. Parent doc
#'   must be readwrite.
#' @param x,y Numeric scalars — starting point in PDF user-space
#'   points (origin at the page's bottom-left). Default `0, 0`.
#' @return The new `pdfium_obj` (type `"path"`), inserted on the
#'   page. The parent page's dirty mark is set.
#' @seealso [pdf_path_line_to()], [pdf_rect_new()],
#'   [pdf_path_set_draw_mode()].
#' @export
pdf_path_new <- function(page, x = 0, y = 0) {
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  ptr <- cpp_path_new(ph$page$ptr, as.numeric(x), as.numeric(y))
  idx <- cpp_page_object_count(ph$page$ptr)
  mark_page_dirty(ph$doc, ph$page$index)
  new_pdfium_obj(ptr, ph$page, idx, "path")
}

#' Create a closed rectangle path on a page
#'
#' Wraps `FPDFPageObj_CreateNewRect` + `FPDFPage_InsertObject`. The
#' new path describes the rectangle `(x, y, x + width, y + height)`
#' with an explicit close — it renders as a stroked / filled
#' rectangle once you set its draw mode and colors.
#'
#' @inheritParams pdf_path_new
#' @param x,y Numeric scalars — bottom-left corner in PDF
#'   user-space points.
#' @param width,height Numeric scalars — rectangle dimensions.
#' @return The new `pdfium_obj` (type `"path"`), inserted on the
#'   page.
#' @seealso [pdf_path_new()], [pdf_path_set_draw_mode()],
#'   [pdf_path_set_fill()].
#' @export
pdf_rect_new <- function(page, x, y, width, height) {
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  checkmate::assert_number(width, lower = 0, finite = TRUE)
  checkmate::assert_number(height, lower = 0, finite = TRUE)
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  ptr <- cpp_rect_new(
    ph$page$ptr,
    as.numeric(x), as.numeric(y),
    as.numeric(width), as.numeric(height)
  )
  idx <- cpp_page_object_count(ph$page$ptr)
  mark_page_dirty(ph$doc, ph$page$index)
  new_pdfium_obj(ptr, ph$page, idx, "path")
}

#' Create a new text page-object on a page
#'
#' Wraps `FPDFPageObj_NewTextObj` (when `font` is a standard-font
#' name) or `FPDFPageObj_CreateTextObj` (when `font` is a custom
#' `pdfium_font` handle from [pdf_font_load_standard()] /
#' [pdf_font_load()]). Either path is followed by an optional
#' `FPDFText_SetText`, `FPDFPageObj_Transform`, and
#' `FPDFPage_InsertObject`.
#'
#' @inheritParams pdf_path_new
#' @param text Character scalar — the text content. Pass `""` to
#'   create an empty text object you'll populate later via
#'   [pdf_text_set_content()].
#' @param font Either a character scalar — one of the 14 PDF
#'   standard font names (see [pdf_font_load_standard()] for the
#'   list) — or a `pdfium_font` handle from
#'   [pdf_font_load_standard()] or [pdf_font_load()]. Default
#'   `"Helvetica"`. Pass a `pdfium_font` handle when you need a
#'   custom TrueType / Type1 font; the standard-font shortcut is
#'   purely for convenience.
#' @param font_size Numeric scalar — font size in points. Default
#'   `12`.
#' @param x,y Numeric scalars — baseline position in PDF user-space
#'   points. Default `0, 0`.
#' @return The new `pdfium_obj` (type `"text"`), inserted on the
#'   page.
#' @seealso [pdf_text_set_content()], [pdf_text_set_render_mode()],
#'   [pdf_obj_set_matrix()], [pdf_font_load_standard()],
#'   [pdf_font_load()].
#' @export
pdf_text_new <- function(page, text,
                          font = "Helvetica",
                          font_size = 12,
                          x = 0, y = 0) {
  checkmate::assert_string(text, na.ok = FALSE)
  checkmate::assert_number(font_size, lower = 0, finite = TRUE)
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  if (inherits(font, "pdfium_font")) {
    if (!is_open(font)) {
      stop("Font handle has been closed.", call. = FALSE)
    }
    ptr <- cpp_text_new_with_font(
      ph$doc$ptr, ph$page$ptr, font$ptr,
      as.numeric(font_size),
      enc2utf8(text),
      as.numeric(x), as.numeric(y)
    )
  } else {
    checkmate::assert_choice(font, .pdfium_standard_fonts)
    ptr <- cpp_text_new(
      ph$doc$ptr, ph$page$ptr,
      font, as.numeric(font_size),
      enc2utf8(text),
      as.numeric(x), as.numeric(y)
    )
  }
  idx <- cpp_page_object_count(ph$page$ptr)
  mark_page_dirty(ph$doc, ph$page$index)
  new_pdfium_obj(ptr, ph$page, idx, "text")
}

#' Remove a page object and destroy it
#'
#' Wraps `FPDFPage_RemoveObject` + `FPDFPageObj_Destroy`. After
#' the call:
#'
#' * The object is gone from the page's content stream.
#' * The C++ object is destroyed.
#' * The R `pdfium_obj` handle's externalptr is cleared so calling
#'   any other `pdf_obj_*` / `pdf_path_*` / `pdf_text_*` function
#'   on it errors cleanly via the existing closed-handle path.
#'
#' Re-fetch via [pdf_page_objects()] if you need an updated obj
#' list after deletions (the page-scoped indices shift).
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()] or one of
#'   the creators ([pdf_path_new()] / [pdf_rect_new()] /
#'   [pdf_text_new()]). Parent doc must be readwrite.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_new()], [pdf_rect_new()], [pdf_text_new()].
#' @export
pdf_obj_delete <- function(obj) {
  ctx <- assert_obj_writable(obj)
  expect_setter_ok(cpp_obj_delete(obj$page$ptr, obj$ptr),
                    "FPDFPage_RemoveObject")
  finalize_obj_setter(ctx)
}
