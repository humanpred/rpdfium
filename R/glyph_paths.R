# Glyph outlines, font metrics, and per-char font info — the
# accessors needed for diagnosing PDF character-mapping issues
# (broken ToUnicode CMaps, fonts that draw one glyph but claim
# another, embedded fonts with subset glyph orderings).
#
# These un-defer the v0.1.0 "Tier 3" items that previously sat in
# the v0.2.0 plan; see dev/reader-writer-audit.md "Tier 3 readers
# landed in 0.1.0" for the rationale.

#' Glyph outline for a single glyph in a text page-object's font
#'
#' Returns the path segments of the glyph rendered at `font_size`
#' in PDF user-space points. Useful for:
#'
#' * Reconstructing challenging character mappings — render the
#'   glyph at the character's reported unicode code point and
#'   compare to a reference rendering of that code point to see
#'   whether the font actually draws what its ToUnicode CMap
#'   claims.
#' * Visualising the glyphs PDFium picked when extracting text.
#' * Computing exact glyph silhouettes for layout / collision
#'   detection beyond what bounding boxes give you.
#'
#' Wraps `FPDFTextObj_GetFont` -> `FPDFFont_GetGlyphPath` ->
#' `FPDFGlyphPath_CountGlyphSegments` /
#' `FPDFGlyphPath_GetGlyphPathSegment`.
#'
#' @section Glyph code interpretation:
#'
#' `glyph_code` is the *font's* glyph identifier, not the unicode
#' code point — though for many fonts they coincide:
#'
#' * **TrueType fonts with `/Identity-H` encoding** (most modern
#'   embedded CID-keyed fonts): glyph code equals unicode code
#'   point. Pass `chars$codepoint` from [pdf_text_chars()].
#' * **TrueType fonts with a `cmap` (e.g. WinAnsi or MacRoman
#'   encoding)**: glyph code is the encoded character code in the
#'   PDF stream, not the unicode value. The unicode <-> glyph map
#'   is opaque through the public PDFium API.
#' * **Type 1 fonts**: glyph code is the encoding-specific
#'   character code (1-byte for almost all PDF Type 1 fonts).
#'
#' If the path comes back empty, the glyph code likely doesn't map
#' to a glyph in this font's encoding — try the character code
#' from the source content stream (visible in tools like `pdfinfo
#' -text`) instead.
#'
#' @param obj A `pdfium_obj` of type `"text"`.
#' @param glyph_code Single non-negative integer; see the section
#'   above.
#' @param font_size Numeric font size in PDF points. When `NA`
#'   (default), uses the text object's own font size — the most
#'   common choice when matching what is drawn on the page.
#' @return A tibble with one row per glyph-path segment:
#'   * `segment_index` integer - 1-based.
#'   * `segment_type` character - `"moveto"`, `"lineto"`,
#'     `"bezierto"`, or `"unknown"`.
#'   * `x`, `y` numeric - point coordinates in PDF user-space
#'     points (the glyph's local coordinate system, scaled to the
#'     requested `font_size`).
#'   * `close_figure` logical - `TRUE` if this segment closes the
#'     current sub-path.
#'   Returns an empty tibble when PDFium reports no glyph outline.
#' @seealso [pdf_glyph_width()], [pdf_text_font_metrics()],
#'   [pdf_text_chars()] for the per-character readout that drives
#'   most "investigate this glyph" workflows,
#'   [pdf_text_obj_rendered_bitmap()] when you want the rendered
#'   pixels instead of the outline.
#' @examples
#' \dontrun{
#' doc <- pdf_doc_open("weird-font.pdf")
#' page <- pdf_page_load(doc, 1)
#' text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(page))[[1]]
#' # First visible character on the page:
#' chars <- pdf_text_chars(page)
#' first <- chars[!chars$is_generated, ][1, ]
#' pdf_glyph_path(text_obj, first$codepoint)
#' }
#' @export
pdf_glyph_path <- function(obj, glyph_code, font_size = NA_real_) {
  check_pdfium_obj(obj, allowed_types = "text")
  checkmate::assert_count(glyph_code)
  checkmate::assert_number(font_size, finite = TRUE, na.ok = TRUE)
  raw <- cpp_text_obj_glyph_path(
    obj$ptr,
    as.integer(glyph_code),
    as.numeric(font_size)
  )
  tibble::tibble(
    segment_index = seq_along(raw$segment_type),
    segment_type  = pdfium_segment_type_name(raw$segment_type),
    x             = raw$x,
    y             = raw$y,
    close_figure  = raw$close
  )
}

#' Width of a glyph in a text page-object's font
#'
#' Returns the advance width of the glyph in PDF user-space points
#' at the requested `font_size`. Useful for measuring glyph layout
#' independent of the bounding-box reported by [pdf_text_chars()],
#' or for spot-checking that a font's reported width matches what
#' it draws.
#'
#' Wraps `FPDFTextObj_GetFont` -> `FPDFFont_GetGlyphWidth`.
#'
#' @inheritParams pdf_glyph_path
#' @return Numeric scalar, the glyph's width in PDF points. `NA`
#'   when PDFium reports failure (typically a font / glyph_code
#'   mismatch).
#' @seealso [pdf_glyph_path()], [pdf_text_font_metrics()].
#' @export
pdf_glyph_width <- function(obj, glyph_code, font_size = NA_real_) {
  check_pdfium_obj(obj, allowed_types = "text")
  checkmate::assert_count(glyph_code)
  checkmate::assert_number(font_size, finite = TRUE, na.ok = TRUE)
  out <- cpp_text_obj_glyph_width(
    obj$ptr,
    as.integer(glyph_code),
    as.numeric(font_size)
  )
  if (!is.finite(out)) NA_real_ else out
}

#' Font ascent and descent for a text page-object's font
#'
#' Returns the font's vertical metrics — *ascent* (the maximum
#' height above the baseline) and *descent* (the maximum depth
#' below the baseline, conventionally a negative number) — at the
#' requested `font_size`. Useful for laying out text with
#' consistent line heights and for converting between PDF text
#' coordinates (baseline-relative) and bounding-box coordinates.
#'
#' Wraps `FPDFFont_GetAscent` and `FPDFFont_GetDescent`.
#'
#' @param obj A `pdfium_obj` of type `"text"`.
#' @param font_size Numeric font size in PDF points (default `1`,
#'   so the result is in "em" units — multiply by the actual font
#'   size you care about).
#' @return A named list with two numeric scalars: `ascent` and
#'   `descent`. Either is `NA` when PDFium can't resolve it.
#' @seealso [pdf_text_font()] for the font's name + weight +
#'   italic-angle metadata; [pdf_glyph_path()] for per-glyph
#'   outlines.
#' @export
pdf_text_font_metrics <- function(obj, font_size = 1) {
  check_pdfium_obj(obj, allowed_types = "text")
  checkmate::assert_number(font_size,
    lower = .Machine$double.eps,
    finite = TRUE
  )
  raw <- cpp_text_obj_font_metrics(obj$ptr, as.numeric(font_size))
  list(
    ascent  = as.numeric(raw$ascent),
    descent = as.numeric(raw$descent)
  )
}
