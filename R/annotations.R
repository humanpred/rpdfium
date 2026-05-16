# Annotation enumeration on a page. PDF annotations cover a wide
# range of overlay objects: text notes, links, highlights, ink
# strokes, stamps, form widgets, redaction marks, etc. PDFium
# exposes them through FPDFPage_GetAnnotCount /
# FPDFPage_GetAnnot, each annotation carrying a subtype code, a
# rectangle, a flags bitmask, and an arbitrary key/value
# dictionary. This module surfaces the structural metadata; for
# form-field-specific values use `pdf_form_fields()`.

# Internal: PDFium FPDF_ANNOT_* subtype code -> human-readable
# subtype string. Indexed by `code + 1` (the codes start at 0 =
# UNKNOWN).
.pdfium_annot_subtypes <- c(
  "unknown",         #  0 FPDF_ANNOT_UNKNOWN
  "text",            #  1 FPDF_ANNOT_TEXT
  "link",            #  2 FPDF_ANNOT_LINK
  "freetext",        #  3 FPDF_ANNOT_FREETEXT
  "line",            #  4 FPDF_ANNOT_LINE
  "square",          #  5 FPDF_ANNOT_SQUARE
  "circle",          #  6 FPDF_ANNOT_CIRCLE
  "polygon",         #  7 FPDF_ANNOT_POLYGON
  "polyline",        #  8 FPDF_ANNOT_POLYLINE
  "highlight",       #  9 FPDF_ANNOT_HIGHLIGHT
  "underline",       # 10 FPDF_ANNOT_UNDERLINE
  "squiggly",        # 11 FPDF_ANNOT_SQUIGGLY
  "strikeout",       # 12 FPDF_ANNOT_STRIKEOUT
  "stamp",           # 13 FPDF_ANNOT_STAMP
  "caret",           # 14 FPDF_ANNOT_CARET
  "ink",             # 15 FPDF_ANNOT_INK
  "popup",           # 16 FPDF_ANNOT_POPUP
  "fileattachment",  # 17 FPDF_ANNOT_FILEATTACHMENT
  "sound",           # 18 FPDF_ANNOT_SOUND
  "movie",           # 19 FPDF_ANNOT_MOVIE
  "widget",          # 20 FPDF_ANNOT_WIDGET
  "screen",          # 21 FPDF_ANNOT_SCREEN
  "printermark",     # 22 FPDF_ANNOT_PRINTERMARK
  "trapnet",         # 23 FPDF_ANNOT_TRAPNET
  "watermark",       # 24 FPDF_ANNOT_WATERMARK
  "threed",          # 25 FPDF_ANNOT_THREED
  "richmedia",       # 26 FPDF_ANNOT_RICHMEDIA
  "xfawidget",       # 27 FPDF_ANNOT_XFAWIDGET
  "redact"           # 28 FPDF_ANNOT_REDACT
)

# Internal helper: doc-or-path (defined locally per PR-stacking
# convention; rebase against phase-6-tier2-cleanup will replace
# this with the canonical helper from R/doc.R).
as_doc_handle <- function(x, arg = "doc") {
  if (is.character(x)) {
    doc <- pdf_open(x)
    return(list(doc = doc, on_exit = function() pdf_close(doc)))
  }
  if (!inherits(x, "pdfium_doc")) {
    stop(sprintf("`%s` must be a `pdfium_doc` or a path to a PDF file.",
                 arg), call. = FALSE)
  }
  if (!is_open(x)) {
    stop("Document has been closed.", call. = FALSE)
  }
  list(doc = x, on_exit = function() invisible(NULL))
}

#' List the annotations on a PDF page
#'
#' Returns one tibble row per annotation on the given page,
#' carrying the structural metadata PDFium surfaces: subtype,
#' bounding box, the 32-bit flags bitmask, and the two text
#' string entries (`/Contents` and `/T`) every annotation kind
#' may carry. For form-widget-specific fields (field type, field
#' value, choice options) use [pdf_form_fields()] instead.
#'
#' Wraps `FPDFPage_GetAnnotCount`, `FPDFPage_GetAnnot`,
#' `FPDFAnnot_GetSubtype`, `FPDFAnnot_GetFlags`,
#' `FPDFAnnot_GetRect`, `FPDFAnnot_GetStringValue`.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc` (in which case `page_num` selects the page).
#' @param page_num One-based page index. Only used when `page` is
#'   a `pdfium_doc`. Ignored otherwise.
#' @return A tibble with columns:
#'   * `annotation_index` integer - 1-based index within the
#'     page's annotation table.
#'   * `subtype` character - one of `"text"`, `"link"`,
#'     `"freetext"`, `"line"`, `"square"`, `"circle"`,
#'     `"polygon"`, `"polyline"`, `"highlight"`, `"underline"`,
#'     `"squiggly"`, `"strikeout"`, `"stamp"`, `"caret"`,
#'     `"ink"`, `"popup"`, `"fileattachment"`, `"sound"`,
#'     `"movie"`, `"widget"`, `"screen"`, `"printermark"`,
#'     `"trapnet"`, `"watermark"`, `"threed"`, `"richmedia"`,
#'     `"xfawidget"`, `"redact"`, or `"unknown"`.
#'     `"widget"` annotations are AcroForm fields; pass the
#'     document to [pdf_form_fields()] for their field-level
#'     metadata.
#'   * `flags` integer - the annotation's 32-bit flag bitmask.
#'     Useful bits: `0x01` invisible, `0x02` hidden, `0x04`
#'     printable, `0x40` read-only, `0x80` locked.
#'   * `bounds_left`, `bounds_bottom`, `bounds_right`,
#'     `bounds_top` - rectangle in PDF user space.
#'   * `contents` character - the annotation's `/Contents` text,
#'     UTF-8 encoded. Empty when absent.
#'   * `title` character - the annotation's `/T` (title /
#'     author) text, UTF-8 encoded. Empty when absent.
#'
#' Returns a 0-row tibble of the same schema when the page has
#' no annotations.
#'
#' @seealso [pdf_form_fields()] for AcroForm-specific accessors.
#' @export
pdf_annotations <- function(page, page_num = 1L) {
  page_h <- as_open_annot_page(page, page_num)
  on.exit(if (page_h$close_on_exit) pdf_close_page(page_h$page),
          add = TRUE)
  raw <- cpp_annots_list(page_h$page$ptr)
  tibble::tibble(
    annotation_index = seq_along(raw$subtype_code),
    subtype          = annotation_subtype_name(raw$subtype_code),
    flags            = as.integer(raw$flags),
    bounds_left      = raw$bounds_left,
    bounds_bottom    = raw$bounds_bottom,
    bounds_right     = raw$bounds_right,
    bounds_top       = raw$bounds_top,
    contents         = raw$contents,
    title            = raw$title
  )
}

# Internal: PDFium subtype code -> string, vectorized. Codes
# outside 0..28 fall through to "unknown".
annotation_subtype_name <- function(codes) {
  out <- rep("unknown", length(codes))
  ok <- !is.na(codes) & codes >= 0L &
    codes < length(.pdfium_annot_subtypes)
  out[ok] <- .pdfium_annot_subtypes[codes[ok] + 1L]
  out
}

# Internal: accept either an open pdfium_page or a pdfium_doc (in
# which case load `page_num`). Returns (page, close_on_exit) so
# the caller can decide whether to free.
as_open_annot_page <- function(page, page_num) {
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) {
      stop("Page has been closed.", call. = FALSE)
    }
    return(list(page = page, close_on_exit = FALSE))
  }
  if (inherits(page, "pdfium_doc")) {
    p <- pdf_load_page(page, page_num)
    return(list(page = p, close_on_exit = TRUE))
  }
  stop("`page` must be a `pdfium_page` or a `pdfium_doc`.",
       call. = FALSE)
}
