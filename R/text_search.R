# Document-level text search. Wraps PDFium's FPDFText_FindStart /
# FindNext family for one page at a time and aggregates the results
# across the document so callers get a single tibble per document.

#' Find every occurrence of a query string in a PDF
#'
#' Searches each page of the document for `query` and returns a row
#' per match with the page number, character offset, matched text,
#' and bounding box in PDF user-space points. Wraps PDFium's
#' `FPDFText_FindStart` / `FPDFText_FindNext` family.
#'
#' Match indexing is character-based: PDFium's text page is an
#' indexable sequence of glyph-derived characters in reading order,
#' and `start_char` is the 0-based offset of the first matched
#' character on that page. The same offset can be cross-referenced
#' against [pdf_text_chars()] output if you need per-character bounds
#' rather than per-match bounds.
#'
#' Multi-line matches (where the matched text wraps across lines)
#' are reported as a single row whose bounding box is the axis-aligned
#' union of every contributing character's bounding box. If you need
#' one rectangle per line for highlighting, expand each row by
#' iterating `pdf_text_chars()` over `start_char:(start_char + char_count - 1)`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param query Single non-empty character string to find. Encoded
#'   to UTF-16LE before being handed to PDFium; any character
#'   representable in UTF-8 works (including supplementary-plane code
#'   points via surrogate pairs).
#' @param case_sensitive If `TRUE`, only exact-case matches are
#'   returned. Default `FALSE` (case-insensitive ASCII letters; PDFium
#'   does not promise case folding for non-ASCII letters).
#' @param whole_word If `TRUE`, the match must be bounded by
#'   word-break characters (whitespace / punctuation) on both sides.
#'   Default `FALSE`.
#' @param consecutive If `TRUE`, after a match the next search resumes
#'   *immediately* after the match end; if `FALSE` (default), PDFium
#'   skips ahead by one character before searching again, so
#'   overlapping matches are not reported.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A tibble with one row per match and columns:
#'   * `page` (integer, 1-based)
#'   * `match_index` (integer, 1-based within `page`)
#'   * `start_char` (integer, 0-based character offset on the page)
#'   * `char_count` (integer, number of characters in the match)
#'   * `text` (character, the matched substring, UTF-8)
#'   * `left`, `bottom`, `right`, `top` (numeric, axis-aligned union
#'      of the matched characters' bounding boxes in PDF user-space
#'      points; `NA` when PDFium reports no bounds, which can happen
#'      for glyphs without a positioned origin)
#'
#'   The tibble has zero rows when no matches are found. Column types
#'   are stable across the zero-row and non-zero-row cases.
#' @seealso [pdf_text()] for whole-page text, [pdf_text_runs()] for
#'   per-text-object structure, [pdf_text_chars()] for per-character
#'   positions.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "unicode.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   pdf_text_search(fixture, "Hello")
#'   pdf_text_search(fixture, "WORLD", case_sensitive = FALSE)
#' }
#' @export
pdf_text_search <- function(doc, query,
                            case_sensitive = FALSE,
                            whole_word = FALSE,
                            consecutive = FALSE,
                            password = NULL) {
  validate_text_search_args(query, case_sensitive, whole_word, consecutive)

  h <- as_doc_handle(doc, password = password)
  on.exit(h$on_exit(), add = TRUE)

  n <- cpp_page_count(h$doc$ptr)
  query_utf8 <- enc2utf8(query)

  rows <- vector("list", n)
  for (i in seq_len(n)) {
    page <- pdf_load_page(h$doc, i)
    raw <- cpp_text_search_page(
      page$ptr, query_utf8,
      match_case = case_sensitive,
      match_whole_word = whole_word,
      consecutive = consecutive
    )
    pdf_close_page(page)

    m <- length(raw$start_char)
    if (m > 0L) {
      rows[[i]] <- tibble::tibble(
        page         = rep.int(as.integer(i), m),
        match_index  = seq_len(m),
        start_char   = as.integer(raw$start_char),
        char_count   = as.integer(raw$char_count),
        text         = as.character(raw$text),
        left         = as.numeric(raw$left),
        bottom       = as.numeric(raw$bottom),
        right        = as.numeric(raw$right),
        top          = as.numeric(raw$top)
      )
    }
  }
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  if (length(rows) == 0L) {
    return(empty_text_search_tibble())
  }
  do.call(rbind, rows)
}

# Internal: argument validators pulled out so pdf_text_search() stays
# under lintr's cyclocomp limit. Each per-arg validator is itself
# simple enough to satisfy cyclocomp.
validate_text_search_args <- function(query, case_sensitive, whole_word,
                                      consecutive) {
  checkmate::assert_string(query, min.chars = 1L)
  checkmate::assert_flag(case_sensitive)
  checkmate::assert_flag(whole_word)
  checkmate::assert_flag(consecutive)
  invisible(NULL)
}

# Internal: the canonical zero-row return shape. Kept in one place so
# the column-type contract is exercised by tests.
empty_text_search_tibble <- function() {
  tibble::tibble(
    page         = integer(),
    match_index  = integer(),
    start_char   = integer(),
    char_count   = integer(),
    text         = character(),
    left         = numeric(),
    bottom       = numeric(),
    right        = numeric(),
    top          = numeric()
  )
}
