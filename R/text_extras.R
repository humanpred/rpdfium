# Text appearance / render-mode read accessors. Page-level rather
# than doc-level because PDFium's text appearance API is indexed by
# the page's character stream.

# FPDF_TEXTRENDERMODE codes from fpdfview.h:
#   -1 UNKNOWN, 0 FILL, 1 STROKE, 2 FILL_STROKE, 3 INVISIBLE,
#   4 FILL_CLIP, 5 STROKE_CLIP, 6 FILL_STROKE_CLIP, 7 CLIP.
.pdfium_text_render_modes <- c(
  "fill",
  "stroke",
  "fill_stroke",
  "invisible",
  "fill_clip",
  "stroke_clip",
  "fill_stroke_clip",
  "clip"
)

#' Text-rendering mode of a text page-object
#'
#' Returns the PDF text-rendering mode (the `Tr` operand) for a text
#' object. The mode determines whether the glyphs are filled,
#' stroked, both, invisible (so the text contributes only to text
#' selection / search), or used as a clipping path. Wraps
#' `FPDFTextObj_GetTextRenderMode`.
#'
#' @param obj A `pdfium_obj` of type `"text"` from
#'   [pdf_page_objects()].
#' @return Character scalar; one of `"fill"` (the default),
#'   `"stroke"`, `"fill_stroke"`, `"invisible"`, `"fill_clip"`,
#'   `"stroke_clip"`, `"fill_stroke_clip"`, `"clip"`, or
#'   `"unknown"` (PDFium couldn't determine).
#' @export
pdf_text_render_mode <- function(obj) {
  check_pdfium_obj(obj, allowed_types = "text")
  code <- cpp_text_render_mode(obj$ptr)
  idx <- code + 1L
  # nocov start — defensive: PDFium render mode is 0..7.
  if (idx < 1L || idx > length(.pdfium_text_render_modes)) {
    return("unknown")
  }
  # nocov end
  .pdfium_text_render_modes[[idx]]
}

#' Per-character fill and stroke colors and text-index mapping
#'
#' Returns one row per character on the page with the fill / stroke
#' RGBA colour PDFium reports for that glyph and the text-position
#' the character occupies in the page's extracted text. Suitable for
#' joining onto [pdf_text_chars()] by `char_index`.
#'
#' Use cases:
#' * Detect invisible / clip-mode text (alpha = 0 in fill *and*
#'   stroke) for text-extraction quality checks.
#' * Distinguish styled-text passages (e.g. highlights with a
#'   non-default fill alpha).
#' * Translate between the character-index space PDFium uses
#'   internally and the extracted-text index space that
#'   [pdf_text_search()]'s `start_char` aligns with — characters
#'   with `text_index = NA` are generated / hyphen / formatting
#'   chars that don't appear in the rendered text string.
#'
#' Wraps `FPDFText_GetFillColor`, `FPDFText_GetStrokeColor`, and
#' `FPDFText_GetTextIndexFromCharIndex`.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc` (the page given by `page_num` will be loaded and
#'   closed internally).
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A tibble with one row per character and columns
#'   `char_index` (1-based), `text_index` (0-based index in the
#'   page's extracted text; `NA` for generated/hyphen/formatting
#'   chars), `fill_red`, `fill_green`, `fill_blue`, `fill_alpha`,
#'   `stroke_red`, `stroke_green`, `stroke_blue`, `stroke_alpha`
#'   (0-255 integers, `NA` when PDFium reports failure).
#' @seealso [pdf_text_chars()] (per-char geometry / codepoint),
#'   [pdf_text_render_mode()] (per-text-object render mode).
#' @export
pdf_text_colors <- function(page, page_num = 1L) {
  ph <- as_open_page(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  raw <- cpp_page_text_colors(ph$page$ptr)
  tibble::tibble(
    char_index    = seq_along(raw$text_index),
    text_index    = raw$text_index,
    fill_red      = raw$fill_red,
    fill_green    = raw$fill_green,
    fill_blue     = raw$fill_blue,
    fill_alpha    = raw$fill_alpha,
    stroke_red    = raw$stroke_red,
    stroke_green  = raw$stroke_green,
    stroke_blue   = raw$stroke_blue,
    stroke_alpha  = raw$stroke_alpha
  )
}
