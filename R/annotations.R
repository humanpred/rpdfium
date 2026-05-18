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

# PDF Annotation flag bit positions (PDF spec 12.5.3, Table 165).
# Indexed by name; value is the 1-based bit position. The decoded
# columns surface the six bits that matter to the typical "read
# this PDF" pipeline. Other bits stay in the raw `flags` column.
.pdfium_annot_flag_bits <- c(
  is_invisible = 1L,
  is_hidden    = 2L,
  is_print     = 3L,
  is_no_view   = 6L,
  is_read_only = 7L,
  is_locked    = 8L
)

# Internal: decode a bitmask vector against one bit position. Used
# inside pdf_annotations() to fill the per-flag logical columns.
annot_flag_decode <- function(flags, bit) {
  bitwAnd(flags, bitwShiftL(1L, bit - 1L)) != 0L
}

#' List the annotations on a PDF page
#'
#' Returns one tibble row per annotation on the given page,
#' carrying the structural metadata PDFium surfaces: subtype,
#' bounding box, raw + decoded flags, the three free-text string
#' entries (`/Contents`, `/T`, `/Subj`), color (`/C`) and interior
#' color (`/IC`), and the annotation's stroke border width. For
#' form-widget-specific fields (field type, field value, choice
#' options) use [pdf_form_fields()] instead.
#'
#' Wraps `FPDFPage_GetAnnotCount`, `FPDFPage_GetAnnot`,
#' `FPDFAnnot_GetSubtype`, `FPDFAnnot_GetFlags`,
#' `FPDFAnnot_GetRect`, `FPDFAnnot_GetStringValue`,
#' `FPDFAnnot_GetColor`, `FPDFAnnot_GetBorder`,
#' `FPDFAnnot_GetAttachmentPoints` / `_HasAttachmentPoints` /
#' `_CountAttachmentPoints`, `FPDFAnnot_GetVertices`, and
#' `FPDFAnnot_GetInkListCount` / `_GetInkListPath`.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc` (in which case `page_num` selects the page).
#' @param page_num One-based page index. Only used when `page` is
#'   a `pdfium_doc`. Ignored otherwise.
#' @return A tibble with columns:
#'   * `annotation_index` integer - 1-based index within the
#'     page's annotation table.
#'   * `subtype_code` integer - the raw `FPDF_ANNOT_*` enum value
#'     (`0..28`). Useful when round-tripping into v0.2.0 writers
#'     that take the enum directly.
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
#'   * `flags` integer - the raw 32-bit `/F` flag bitmask.
#'   * `is_invisible`, `is_hidden`, `is_print`, `is_no_view`,
#'     `is_read_only`, `is_locked` logical - decoded flag bits
#'     (bits 1, 2, 3, 6, 7, 8 from PDF spec Table 165).
#'   * `bounds_left`, `bounds_bottom`, `bounds_right`,
#'     `bounds_top` - rectangle in PDF user space.
#'   * `contents` character - the annotation's `/Contents` body
#'     text, UTF-8 encoded. Empty when absent.
#'   * `title` character - the annotation's `/T` (title / author)
#'     text. Empty when absent.
#'   * `subject` character - the annotation's `/Subj` subject
#'     line. Empty when absent.
#'   * `color_red`, `color_green`, `color_blue`, `color_alpha`
#'     numeric - the annotation's `/C` color components in
#'     0..1. `NA` when the annotation has no `/C`.
#'   * `interior_red`, `interior_green`, `interior_blue`,
#'     `interior_alpha` numeric - the annotation's `/IC`
#'     interior color components in 0..1 (used by line/square/
#'     circle / polygon subtypes). `NA` otherwise.
#'   * `border_width` numeric - the stroke border width PDFium
#'     reports for `/Border` / `/BS`. `NA` for subtypes that
#'     don't carry a border.
#'   * `quad_points` list-column - for highlights, underlines,
#'     strikeouts, squigglies (and any other quad-bearing subtype),
#'     a numeric matrix with one row per quad set and eight
#'     columns `x1, y1, x2, y2, x3, y3, x4, y4` in PDF user space.
#'     `NULL` for annotations without `/QuadPoints`. Multi-line
#'     highlights produce one row per line.
#'   * `vertices` list-column - for line / polygon / polyline
#'     annotations, an N-by-2 numeric matrix with columns `x, y`.
#'     `NULL` for other subtypes.
#'   * `ink_paths` list-column - for ink annotations, a list of
#'     stroke paths, each an N-by-2 numeric matrix `x, y`.
#'     `NULL` for non-ink annotations. One element per ink
#'     stroke; a single-stroke ink annotation produces a length-1
#'     list.
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
  flags <- as.integer(raw$flags)
  decode <- function(bit_name) {
    annot_flag_decode(flags, .pdfium_annot_flag_bits[[bit_name]])
  }
  tibble::tibble(
    annotation_index = seq_along(raw$subtype_code),
    subtype_code     = as.integer(raw$subtype_code),
    subtype          = annotation_subtype_name(raw$subtype_code),
    flags            = flags,
    is_invisible     = decode("is_invisible"),
    is_hidden        = decode("is_hidden"),
    is_print         = decode("is_print"),
    is_no_view       = decode("is_no_view"),
    is_read_only     = decode("is_read_only"),
    is_locked        = decode("is_locked"),
    bounds_left      = raw$bounds_left,
    bounds_bottom    = raw$bounds_bottom,
    bounds_right     = raw$bounds_right,
    bounds_top       = raw$bounds_top,
    contents         = raw$contents,
    title            = raw$title,
    subject          = raw$subject,
    color_red        = raw$color_red,
    color_green      = raw$color_green,
    color_blue       = raw$color_blue,
    color_alpha      = raw$color_alpha,
    interior_red     = raw$interior_red,
    interior_green   = raw$interior_green,
    interior_blue    = raw$interior_blue,
    interior_alpha   = raw$interior_alpha,
    border_width     = raw$border_width,
    quad_points      = raw$quad_points,
    vertices         = raw$vertices,
    ink_paths        = raw$ink_paths
  )
}

# Internal: code <-> name helpers for the annotation subtype enum.
# `annotation_subtype_name(codes)` already maps codes -> strings; this
# is its inverse for use by v0.2.0 writers. Unknown / NA strings map
# to FPDF_ANNOT_UNKNOWN (0).
pdfium_annot_subtype_code <- function(names) {
  hit <- match(tolower(as.character(names)), .pdfium_annot_subtypes)
  ifelse(is.na(hit), 0L, hit - 1L)
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
