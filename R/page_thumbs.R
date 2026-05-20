# Page-level extras: embedded thumbnails and auto-detected web-link
# readout. Both wrap small chunks of PDFium's public API
# (fpdf_thumbnail.h and the FPDFLink_*WebLinks* family in
# fpdf_text.h) so 0.1.0 covers the full page-level read surface.
#
# Thumbnails are the optional /Thumb image stream a PDF authoring
# tool can embed on a page; most R-produced PDFs lack them, so the
# typical result is `raw(0)`.
#
# pdf_text_weblinks() differs from pdf_page_links() — the latter
# enumerates link *annotations* defined by the PDF author (clickable
# rectangles with an associated action), while this function runs
# PDFium's URL detector over the page's *extracted text* and returns
# the spans that look like URLs. Reading a scanned PDF that mentions
# "https://example.com" in OCR'd text will produce a row here but
# not in `pdf_page_links()`.

#' Page embedded thumbnail
#'
#' Returns the bytes of a page's embedded `/Thumb` image stream, if
#' the PDF carries one. PDF authoring tools sometimes embed a
#' low-resolution preview alongside each page; readers can display
#' that thumbnail without rendering the full page. Wraps
#' `FPDFPage_GetRawThumbnailData` and `FPDFPage_GetDecodedThumbnailData`.
#'
#' Most PDFs produced by Cairo, LaTeX, or web tools do not embed
#' thumbnails — this function returns `raw(0)` in that common case.
#'
#' @param page A `pdfium_page` from [pdf_page_load()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @param decoded If `TRUE` (default) returns the decoded bitmap
#'   bytes after PDFium has applied any stream filter (e.g.
#'   `/FlateDecode`). If `FALSE`, returns the raw filtered bytes —
#'   useful when a caller wants to save the thumbnail back to disk
#'   in its original encoded form, or pipe it through a different
#'   decoder.
#' @return A `raw` vector. Length zero when the page has no `/Thumb`.
#' @seealso [pdf_render_page()] to rasterize the full page instead.
#' @export
pdf_page_thumbnail <- function(page, page_num = 1L, decoded = TRUE) {
  checkmate::assert_flag(decoded)
  page <- as_open_page(page, page_num)
  if (decoded) {
    cpp_page_thumbnail_decoded(page$ptr)
  } else {
    cpp_page_thumbnail_raw(page$ptr)
  }
}

#' Auto-detected web links in a page's text
#'
#' Returns one row per URL that PDFium's web-link detector finds in
#' the page's extracted text. Detected patterns include `http://...`,
#' `https://...`, `www.example.com`, and `mailto:user@host`. Wraps
#' `FPDFLink_LoadWebLinks` plus `FPDFLink_GetURL`,
#' `FPDFLink_GetTextRange`, `FPDFLink_CountRects`, and
#' `FPDFLink_GetRect`.
#'
#' This is distinct from [pdf_page_links()], which enumerates the
#' clickable link *annotations* declared by the PDF author. Use
#' `pdf_text_weblinks()` when the URL appears as plain text on the
#' page (no link annotation), and `pdf_page_links()` when you want
#' the explicit clickable regions.
#'
#' Multi-line URLs produce one row whose bounding box is the
#' axis-aligned union of every contributing line's rectangle. If you
#' need a rectangle per line, pair `start_char` and `char_count` with
#' [pdf_text_chars()] over `start_char:(start_char + char_count - 1L)`.
#'
#' @inheritParams pdf_page_thumbnail
#' @return A tibble with one row per detected URL and columns:
#'   * `url` (character) — the matched URL string. UTF-8.
#'   * `start_char` (integer) — 0-based character offset of the URL
#'     on the page's text page.
#'   * `char_count` (integer) — number of characters in the matched
#'     span.
#'   * `left`, `bottom`, `right`, `top` (numeric) — axis-aligned
#'     union of the URL's per-line rectangles in PDF user-space
#'     points. `NA` when PDFium reports no bounds.
#'
#'   Returns a 0-row tibble of the same schema when no URLs are
#'   detected.
#' @seealso [pdf_page_links()] for link annotations,
#'   [pdf_text_search()] for arbitrary string search.
#' @export
pdf_text_weblinks <- function(page, page_num = 1L) {
  page <- as_open_page(page, page_num)
  raw <- cpp_page_weblinks(page$ptr)
  n <- length(raw$url)
  if (n == 0L) {
    return(empty_text_weblinks_tibble())
  }
  tibble::tibble(
    url        = as.character(raw$url),
    start_char = as.integer(raw$start_char),
    char_count = as.integer(raw$char_count),
    left       = as.numeric(raw$left),
    bottom     = as.numeric(raw$bottom),
    right      = as.numeric(raw$right),
    top        = as.numeric(raw$top)
  )
}

# Internal: zero-row return shape for pdf_text_weblinks().
empty_text_weblinks_tibble <- function() {
  tibble::tibble(
    url        = character(),
    start_char = integer(),
    char_count = integer(),
    left       = numeric(),
    bottom     = numeric(),
    right      = numeric(),
    top        = numeric()
  )
}
