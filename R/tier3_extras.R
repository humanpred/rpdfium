# "Tier 3" niche read-side helpers that don't fit any of the
# bigger modules:
#
# - pdf_text_obj_rendered_bitmap renders a single text page-object
#   at the requested scale.
# - pdf_attachment_dict_value does ad-hoc lookups of an
#   attachment-dictionary entry.
# - pdf_text_char_obj_index reverse-maps a char-index to a
#   page-object-index.

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
  if (!is.numeric(scale) || length(scale) != 1L || !is.finite(scale) ||
    scale <= 0) {
    stop("`scale` must be a single positive finite numeric.",
      call. = FALSE
    )
  }
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

#' Look up an attachment-dictionary entry by key
#'
#' PDF attachments carry a `/Params` dictionary with metadata about
#' the embedded file (size, modification date, checksums, MIME
#' type, custom keys). [pdf_attachments()] surfaces the common
#' entries; this function reads an arbitrary key. Wraps
#' `FPDFAttachment_HasKey` + `FPDFAttachment_GetValueType` +
#' `FPDFAttachment_GetStringValue`.
#'
#' Only string- and name-typed values are returned as character
#' scalars. For numeric / boolean / dict values the function
#' reports `has_key = TRUE` and `value_type` accordingly but
#' `value = NA_character_` (use [pdf_attachments()] for the
#' structured size/date/checksum readouts).
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param attachment_index One-based index into the attachment list.
#' @param key The attachment-dict key as a single non-empty
#'   character string (e.g. `"Subtype"`, `"AFRelationship"`).
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A list:
#'   * `has_key` (logical) — `TRUE` when the attachment dict
#'     contains the key.
#'   * `value_type` (integer) — PDFium's `FPDF_OBJECT_*` enum
#'     value (`0`=unknown, `1`=boolean, `2`=number, `3`=string,
#'     `4`=name, ...). `NA` when the key is absent.
#'   * `value` (character) — the string / name value;
#'     `NA_character_` when the value is not string-typed.
#' @seealso [pdf_attachments()].
#' @export
pdf_attachment_dict_value <- function(doc, attachment_index, key,
                                      password = NULL) {
  validate_positive_int(attachment_index, "attachment_index")
  validate_nonempty_char(key, "key")
  h <- as_doc_handle(doc, "doc", password = password)
  on.exit(h$on_exit(), add = TRUE)
  raw <- cpp_attachment_dict_value(
    h$doc$ptr,
    as.integer(attachment_index - 1L),
    enc2utf8(key)
  )
  val_chr <- as.character(raw$value)
  # nocov start — defensive: cpp always returns length-1 chr.
  if (length(val_chr) == 0L) val_chr <- NA_character_
  # nocov end
  list(
    has_key    = as.logical(raw$has_key),
    value_type = as.integer(raw$value_type),
    value      = val_chr[[1L]]
  )
}

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
  if (!is.numeric(char_index) || length(char_index) != 1L ||
    !is.finite(char_index) || char_index < 1L) {
    stop("`char_index` must be a single positive integer.",
      call. = FALSE
    )
  }
  ph <- as_open_page_pair(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  idx <- cpp_text_char_obj_index(
    ph$page$ptr,
    as.integer(char_index - 1L)
  )
  if (idx < 0L) NA_integer_ else as.integer(idx)
}
