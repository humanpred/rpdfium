# Phase-6 page-level additions: page-box readers (MediaBox /
# CropBox / BleedBox / TrimBox / ArtBox), per-character text
# extraction (pdf_text_chars), and weblink enumeration
# (pdf_page_links). All three are page-level wrappers and accept
# either an open `pdfium_page` or a `pdfium_doc` + page_num
# combination, following the same convention as
# pdf_render_page() / pdf_text_runs() / pdf_annotations().

# Internal: resolve a page-or-doc argument into an open page +
# close-on-exit flag. Same pattern as
# as_open_annot_page in R/annotations.R (open PR C); the rebase
# will dedupe.
as_open_page_pair <- function(page, page_num) {
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) stop("Page has been closed.", call. = FALSE)
    return(list(page = page, close_on_exit = FALSE))
  }
  if (inherits(page, "pdfium_doc")) {
    if (!is_open(page)) stop("Document has been closed.", call. = FALSE)
    p <- pdf_load_page(page, page_num)
    return(list(page = p, close_on_exit = TRUE))
  }
  stop("`page` must be a `pdfium_page` or a `pdfium_doc`.",
       call. = FALSE)
}

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
                         box = c("media", "crop", "bleed",
                                 "trim", "art")) {
  box <- match.arg(box)
  ph <- as_open_page_pair(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  cpp_page_box(ph$page$ptr, box)
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
#'
#' Returns a 0-row tibble of the same schema when the page has no
#' text.
#'
#' @seealso [pdf_text_runs()], [pdf_text()].
#' @export
pdf_text_chars <- function(page, page_num = 1L) {
  ph <- as_open_page_pair(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  raw <- cpp_page_text_chars(ph$page$ptr)
  tibble::tibble(
    char_index    = seq_along(raw$codepoint),
    codepoint     = as.integer(raw$codepoint),
    char          = raw$char,
    bounds_left   = raw$bounds_left,
    bounds_bottom = raw$bounds_bottom,
    bounds_right  = raw$bounds_right,
    bounds_top    = raw$bounds_top,
    font_size     = raw$font_size,
    is_generated  = raw$is_generated,
    is_hyphen     = raw$is_hyphen
  )
}

# PDF action types from fpdf_doc.h. Indexed by code + 1; 0 means
# "no /A action, only /Dest" which we map to "goto" for callers'
# convenience.
.pdfium_action_types <- c(
  "goto",         # 0: no /A, /Dest only
  "unsupported",  # 1: PDFACTION_UNSUPPORTED
  "goto",         # 2: PDFACTION_GOTO
  "remote_goto",  # 3: PDFACTION_REMOTEGOTO
  "uri",          # 4: PDFACTION_URI
  "launch"        # 5: PDFACTION_LAUNCH
)

#' List the clickable links on a page
#'
#' Returns one tibble row per link annotation on the page, with
#' the link's bounding rectangle and the action it carries
#' (target page for internal links, URL for external links).
#' Wraps `FPDFLink_Enumerate` plus the per-link
#' `FPDFLink_GetAnnotRect`, `FPDFLink_GetAction` / `_GetDest`,
#' `FPDFAction_GetType`, `FPDFAction_GetURIPath`, and
#' `FPDFDest_GetDestPageIndex`.
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
#'     or application), `"unsupported"`.
#'   * `uri` character - non-empty for `action_type == "uri"`;
#'     the target URL.
#'   * `dest_page_num` integer - non-NA for `goto` /
#'     `remote_goto`; the 1-based destination page within the
#'     current (or remote) document.
#'
#' Returns a 0-row tibble of the same schema when the page has no
#' link annotations.
#' @export
pdf_page_links <- function(page, page_num = 1L) {
  ph <- as_open_page_pair(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  # The link enumerator needs the doc handle for action / dest
  # resolution. Pull it off the page's parent reference.
  doc_ptr <- ph$page$doc$ptr
  raw <- cpp_page_links(doc_ptr, ph$page$ptr)
  action_codes <- as.integer(raw$action_code)
  idx <- action_codes + 1L
  safe_idx <- pmax(pmin(idx, length(.pdfium_action_types)), 1L)
  action_type <- ifelse(
    idx < 1L | idx > length(.pdfium_action_types),
    "unsupported",
    .pdfium_action_types[safe_idx]
  )
  tibble::tibble(
    link_index    = seq_along(action_codes),
    bounds_left   = raw$bounds_left,
    bounds_bottom = raw$bounds_bottom,
    bounds_right  = raw$bounds_right,
    bounds_top    = raw$bounds_top,
    action_type   = action_type,
    uri           = raw$uri,
    dest_page_num = as.integer(raw$dest_page_num)
  )
}
