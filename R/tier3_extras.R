# "Tier 3" niche read-side helpers that don't fit any of the
# bigger modules:
#
# - pdf_text_obj_rendered_bitmap renders a single text page-object
#   at the requested scale.
# - pdf_text_char_obj_index reverse-maps a char-index to a
#   page-object-index.
#
# (Note: pdf_attachment_dict_value previously lived here too but
# moved to R/attachments.R when attachments switched to a
# handle-based reader in ADR-017 / Phase 2.5c.)

#' Rendered bitmap of a single text page-object
#'
#' Returns a `pdfium_bitmap` of the rendered glyphs in `obj`,
#' scaled by `scale` (1.0 = 1 PDF point per pixel). Useful for
#' previewing a single text run without rendering the full page.
#' Wraps `FPDFTextObj_GetRenderedBitmap`.
#'
#' @param obj A `pdfium_obj` of type `"text"` from
#'   [pdf_page_objects()].
#' @param scale Numeric scale factor (default `1`). Larger values
#'   produce higher-resolution bitmaps.
#' @return A `pdfium_bitmap` integer matrix (nativeRaster ABGR
#'   encoding) or `NULL` when PDFium reports failure.
#' @seealso [pdf_render_page()] for whole-page rendering;
#'   [pdf_image_bitmap()] for image objects.
#' @export
pdf_text_obj_rendered_bitmap <- function(obj, scale = 1) {
  checkmate::assert_number(scale,
    lower = .Machine$double.eps,
    finite = TRUE
  )
  check_pdfium_obj(obj, allowed_types = "text")
  m <- cpp_text_obj_rendered_bitmap(
    obj$page$doc$ptr, obj$page$ptr,
    obj$ptr, as.numeric(scale)
  )
  # nocov start — defensive: cpp returns the bitmap or raises,
  # never silently NULL.
  if (is.null(m)) {
    return(NULL)
  }
  # nocov end
  class(m) <- c("pdfium_bitmap", "nativeRaster")
  attr(m, "channels") <- 4L
  attr(m, "dpi") <- 72 * as.numeric(scale)
  attr(m, "source_page") <- obj$page$index %||% NA_integer_
  attr(m, "rotation_applied") <- 0L
  m
}

# `||` like dplyr's coalesce; avoids importing rlang.
`%||%` <- function(x, y) if (is.null(x)) y else x

# `pdf_attachment_dict_value()` moved to R/attachments.R — it now
# takes a `pdfium_attachment` handle (see ADR-017 / Phase 2.5c).

#' Reverse-map a character index to its page-object index
#'
#' Given a 1-based `char_index` on the page's text page (matching
#' the `char_index` column of [pdf_text_chars()]), return the
#' 1-based page-object index of the text run that contains it.
#' Wraps `FPDFText_GetTextObject` plus a lookup into the page's
#' object table.
#'
#' Useful for jumping from a per-character readout back to the
#' parent text page object's style / position metadata in
#' [pdf_text_runs()] (which uses the same `obj_index`).
#'
#' @inheritParams pdf_text_chars
#' @param char_index One-based character index (matches
#'   `pdf_text_chars()$char_index`).
#' @return Integer scalar — the 1-based page-object index, or `NA`
#'   when the character has no associated page object (e.g.
#'   PDFium-synthesised whitespace).
#' @seealso [pdf_text_chars()], [pdf_text_runs()].
#' @export
pdf_text_char_obj_index <- function(page, char_index, page_num = 1L) {
  checkmate::assert_count(char_index, positive = TRUE)
  page <- as_open_page(page, page_num)
  idx <- cpp_text_char_obj_index(
    page$ptr,
    as.integer(char_index - 1L)
  )
  na_if_negative(idx)
}
