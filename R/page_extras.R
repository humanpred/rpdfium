# Phase-6 page-level additions: page-box readers (MediaBox /
# CropBox / BleedBox / TrimBox / ArtBox), per-character text
# extraction (pdf_text_chars), and weblink enumeration
# (pdf_page_links). All three are page-level wrappers and accept
# either an open `pdfium_page` or a `pdfium_doc` + page_num
# combination, following the same convention as
# pdf_render_page() / pdf_text_runs() / pdf_annotations().

#' Read a page's bounding box
#'
#' PDF pages can carry up to five named boxes:
#' [MediaBox](https://www.iso.org/standard/63534.html) (physical
#' page extent), CropBox (visible / printable extent), BleedBox
#' (printer trim with bleed), TrimBox (final page after cutting),
#' and ArtBox (meaningful content). [pdf_page_size()] returns the
#' MediaBox's width/height; this function returns any of the five
#' boxes as a `(left, bottom, right, top)` named vector.
#'
#' Wraps `FPDFPage_GetMediaBox` / `_GetCropBox` / `_GetBleedBox`
#' / `_GetTrimBox` / `_GetArtBox`.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is
#'   a `pdfium_doc`. Ignored otherwise.
#' @param box One of `"media"` (default), `"crop"`, `"bleed"`,
#'   `"trim"`, `"art"`.
#' @return A named numeric vector with elements `left`, `bottom`,
#'   `right`, `top` (PDF user-space points). Every element is
#'   `NA` when the requested box is not declared on the page.
#'   Note that per the PDF spec a viewer falls back from a
#'   missing CropBox / BleedBox / TrimBox / ArtBox to the
#'   MediaBox, but `pdf_page_box()` does not - if you want the
#'   "what would render" rectangle, call [pdf_page_box()] for
#'   `"media"` after testing whether a more specific box exists.
#' @seealso [pdf_page_size()] (always MediaBox width/height).
#' @export
pdf_page_box <- function(page, page_num = 1L,
                         box = c(
                           "media", "crop", "bleed",
                           "trim", "art"
                         )) {
  box <- match.arg(box)
  page <- as_open_page(page, page_num)
  cpp_page_box(page$ptr, box)
}

#' Per-character text extraction
#'
#' Returns one tibble row per character on the page, with the
#' character's Unicode codepoint and UTF-8 form, glyph bounding
#' box, effective font size, and two PDF flags indicating
#' "generated" characters (whitespace PDFium inferred between
#' positioned glyphs) and end-of-line "soft" hyphens. Wraps
#' `FPDFText_LoadPage` plus `FPDFText_CountChars` /
#' `_GetUnicode` / `_GetCharBox` / `_GetFontSize` /
#' `_IsGenerated` / `_IsHyphen`.
#'
#' This is the per-character analog of [pdf_text_runs()]
#' (per-text-object) and [pdf_text()] (per-page). The three
#' coexist: use `pdf_text()` when you just want the strings,
#' `pdf_text_runs()` for object-level positions, and
#' `pdf_text_chars()` when you need glyph-level geometry (e.g.
#' word segmentation, character-by-character layout analysis).
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is
#'   a `pdfium_doc`. Ignored otherwise.
#' @return A tibble with columns:
#'   * `char_index` integer - 1-based position in the page's
#'     character stream.
#'   * `codepoint` integer - Unicode code point.
#'   * `char` character - UTF-8 character; empty for surrogate
#'     halves or PDFium's NUL sentinel.
#'   * `bounds_left`, `bounds_bottom`, `bounds_right`,
#'     `bounds_top` - glyph bounding box in PDF user space.
#'   * `font_size` numeric - effective glyph height in user-space
#'     points (the run's font size times the text matrix scale).
#'   * `is_generated` logical - `TRUE` for whitespace PDFium
#'     synthesised between positioned glyphs (the source PDF
#'     does not carry a character there; PDFium infers one for
#'     text-extraction consumers).
#'   * `is_hyphen` logical - `TRUE` for end-of-line soft hyphens.
#'   * `origin_x`, `origin_y` - the character's glyph origin point
#'     in PDF user space (`FPDFText_GetCharOrigin`). Distinct from
#'     the bounding-box corners; for many fonts the origin is at
#'     the baseline left of the glyph.
#'   * `loose_left`, `loose_bottom`, `loose_right`, `loose_top` -
#'     the "loose" bounding box covering the entire glyph cell
#'     (font ascent / descent included), not just the glyph
#'     outline. Use these when you need consistent line heights;
#'     use `bounds_*` for the tight glyph extent.
#'   * `unicode_map_error` logical - `TRUE` when PDFium detected
#'     that the character's ToUnicode CMap is malformed for this
#'     glyph (the codepoint reported may be the PDF's `
#'     fallback rather than the intended character).
#'   * `text_index` integer - 0-based position in the *extractable*
#'     text string (i.e. the linear `pdf_text()` output) for this
#'     character, or `NA` for synthesised whitespace and other
#'     characters that don't appear in the extracted text.
#'   * `char_font_name` character - the font name PDFium reports
#'     for this specific character (via `FPDFText_GetFontInfo`).
#'     Per-character because pages can mix fonts within a single
#'     text run after PDFium re-flows characters during extraction.
#'   * `char_font_flags` integer - the PDF Font Descriptor `/Flags`
#'     bitmask for this character's font (PDF spec Table 121).
#'     Useful for detecting `/Symbolic` (bit 3) or
#'     `/AllCap` (bit 17) fonts whose ToUnicode mapping may be
#'     unreliable.
#'
#' Returns a 0-row tibble of the same schema when the page has no
#' text.
#'
#' @seealso [pdf_text_runs()], [pdf_text()].
#' @export
pdf_text_chars <- function(page, page_num = 1L) {
  page <- as_open_page(page, page_num)
  raw <- cpp_page_text_chars(page$ptr)
  font <- cpp_text_char_font_info(page$ptr)
  tibble::as_tibble(build_text_chars_cols(raw, font))
}

# Internal: assemble the per-character readout into a flat named
# list that `tibble::as_tibble()` can consume. Pulled out so
# `pdf_text_chars()` itself stays under the lintr cyclocomp limit
# (every named tibble argument counts as one branch).
build_text_chars_cols <- function(raw, font) {
  list(
    char_index = seq_along(raw$codepoint),
    codepoint = as.integer(raw$codepoint),
    char = raw$char,
    bounds_left = raw$bounds_left,
    bounds_bottom = raw$bounds_bottom,
    bounds_right = raw$bounds_right,
    bounds_top = raw$bounds_top,
    font_size = raw$font_size,
    is_generated = raw$is_generated,
    is_hyphen = raw$is_hyphen,
    origin_x = raw$origin_x,
    origin_y = raw$origin_y,
    loose_left = raw$loose_left,
    loose_bottom = raw$loose_bottom,
    loose_right = raw$loose_right,
    loose_top = raw$loose_top,
    unicode_map_error = raw$unicode_map_error,
    text_index = as.integer(raw$text_index),
    char_font_name = as.character(font$font_name),
    char_font_flags = as.integer(font$font_flags)
  )
}

#' Locate the character index nearest a (x, y) point on a page
#'
#' Returns the 1-based index of the character whose bounding box
#' contains (or is closest within `tolerance`) the given point. Wraps
#' `FPDFText_GetCharIndexAtPos`.
#'
#' @inheritParams pdf_text_chars
#' @param x,y Point in PDF user-space points.
#' @param tolerance Numeric of length 1 or 2; absolute slack
#'   (in PDF points) PDFium is allowed to use when no character
#'   directly contains `(x, y)`. Length-2 sets `x` and `y` tolerance
#'   independently. Default `2`.
#' @return Integer scalar — the 1-based character index, or `NA` when
#'   no character is within tolerance.
#' @seealso [pdf_text_chars()].
#' @export
pdf_text_char_at_point <- function(page, x, y, tolerance = 2,
                                   page_num = 1L) {
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  tolerance <- validate_char_at_point_tolerance(tolerance)
  page <- as_open_page(page, page_num)
  idx0 <- cpp_text_char_at_pos(
    page$ptr,
    as.numeric(x), as.numeric(y),
    as.numeric(tolerance[[1L]]),
    as.numeric(tolerance[[2L]])
  )
  if (idx0 < 0L) {
    return(NA_integer_)
  }
  as.integer(idx0 + 1L)
}

#' Map between PDFium's "all characters" and "extractable text" indices
#'
#' PDFium's text page surfaces two parallel views of the page's text:
#' the full *character* list (positioned glyphs including
#' PDFium-synthesised whitespace between them), and the *extractable
#' text* string (only characters that appear in [pdf_text()]'s
#' output). These helpers translate between the two indexing systems.
#'
#' `pdf_text_index_from_char()` converts a 1-based `char_index`
#' (matches `pdf_text_chars()`'s `char_index` column) into the
#' 0-based position in the extractable text string, or `NA` if the
#' character has no extractable-text counterpart.
#'
#' `pdf_text_char_from_text_index()` does the reverse: given a
#' 0-based text-string index, returns the 1-based `char_index`.
#'
#' Wraps `FPDFText_GetTextIndexFromCharIndex` /
#' `FPDFText_GetCharIndexFromTextIndex`.
#'
#' @inheritParams pdf_text_chars
#' @param char_index One-based character index (matches
#'   `pdf_text_chars()$char_index`).
#' @param text_index Zero-based offset into the extractable text
#'   string.
#' @return An integer scalar — the converted index, or `NA` when the
#'   character has no counterpart in the other indexing system.
#' @seealso [pdf_text_chars()], [pdf_text()], [pdf_text_search()].
#' @export
pdf_text_index_from_char <- function(page, char_index, page_num = 1L) {
  checkmate::assert_int(char_index)
  page <- as_open_page(page, page_num)
  out <- cpp_text_text_index_from_char(
    page$ptr,
    as.integer(char_index - 1L)
  )
  if (out < 0L) NA_integer_ else as.integer(out)
}

#' @rdname pdf_text_index_from_char
#' @export
pdf_text_char_from_text_index <- function(page, text_index,
                                          page_num = 1L) {
  checkmate::assert_int(text_index)
  page <- as_open_page(page, page_num)
  out <- cpp_text_char_index_from_text(
    page$ptr,
    as.integer(text_index)
  )
  if (out < 0L) NA_integer_ else as.integer(out + 1L)
}

#' List the clickable links on a page
#'
#' Returns one tibble row per link annotation on the page, with
#' the link's bounding rectangle and the action it carries
#' (target page for internal links, URL for external links).
#' Wraps `FPDFLink_Enumerate` plus the per-link
#' `FPDFLink_GetAnnotRect`, `FPDFLink_GetAction` / `_GetDest`,
#' `FPDFAction_GetType`, `FPDFAction_GetURIPath`,
#' `FPDFAction_GetFilePath`, and `FPDFDest_GetDestPageIndex`.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is
#'   a `pdfium_doc`. Ignored otherwise.
#' @return A tibble with columns:
#'   * `link_index` integer - 1-based position in the page's
#'     link table.
#'   * `bounds_left`, `bounds_bottom`, `bounds_right`,
#'     `bounds_top` - link hit-test rectangle in PDF user space.
#'   * `action_type` character - one of `"goto"` (jump within
#'     the document), `"remote_goto"` (jump to a remote PDF),
#'     `"uri"` (open a URL), `"launch"` (launch an external file
#'     or application), `"embedded_goto"` (jump into an embedded
#'     file), or `"unsupported"`.
#'   * `uri` character - the target URL when
#'     `action_type == "uri"`; `NA` otherwise.
#'   * `filepath` character - the external file path when
#'     `action_type` is `"remote_goto"` / `"launch"` /
#'     `"embedded_goto"`; `NA` otherwise.
#'   * `dest_page_num` integer - 1-based destination page within
#'     the current (or remote) document; `NA` when not resolvable.
#'   * `dest_view` character - destination view mode (`"xyz"`,
#'     `"fit"`, `"fith"`, `"fitv"`, `"fitr"`, `"fitb"`, `"fitbh"`,
#'     `"fitbv"`, `"unknown"`).
#'   * `dest_x`, `dest_y`, `dest_zoom` numeric - explicit point and
#'     zoom for XYZ destinations / scroll offsets for the Fit*
#'     variants; `NA` for components the destination doesn't set.
#'   * `quad_points` list-column - per-line quad sets for multi-line
#'     links. An N-by-8 numeric matrix with columns `x1, y1, x2,
#'     y2, x3, y3, x4, y4` in PDF user space (one row per line),
#'     or `NULL` for links that carry no `/QuadPoints` (single-rect
#'     links). Same shape as `pdf_annotations()$quad_points`.
#'
#' Returns a 0-row tibble of the same schema when the page has no
#' link annotations.
#' @export
pdf_page_links <- function(page, page_num = 1L) {
  page <- as_open_page(page, page_num)
  # The link enumerator needs the doc handle for action / dest
  # resolution. Pull it off the page's parent reference.
  raw <- cpp_page_links(page$doc$ptr, page$ptr)
  tibble::tibble(
    link_index    = seq_along(raw$action_code),
    bounds_left   = raw$bounds_left,
    bounds_bottom = raw$bounds_bottom,
    bounds_right  = raw$bounds_right,
    bounds_top    = raw$bounds_top,
    action_type   = pdfium_action_type_name(raw$action_code),
    uri           = na_if_empty(raw$uri),
    filepath      = na_if_empty(raw$filepath),
    dest_page_num = as.integer(raw$dest_page_num),
    dest_view     = pdfium_dest_view_name(raw$dest_view),
    dest_x        = raw$dest_x,
    dest_y        = raw$dest_y,
    dest_zoom     = raw$dest_zoom,
    quad_points   = raw$quad_points
  )
}

# Internal: normalise `tolerance` for pdf_text_char_at_point() to a
# length-2 c(x_tol, y_tol). Accepts length-1 (replicated) or
# length-2 numeric.
validate_char_at_point_tolerance <- function(tolerance) {
  checkmate::assert_numeric(tolerance,
    finite = TRUE,
    min.len = 1L, max.len = 2L,
    any.missing = FALSE
  )
  if (length(tolerance) == 1L) tolerance <- c(tolerance, tolerance)
  tolerance
}
