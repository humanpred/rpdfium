# Per-attribute readers for `pdfium_annot` handles.
#
# The handle is constructed by `pdf_annotations(page)` (or via the
# writer-side `pdf_annot_new()` once Phase 6 lands). Each reader
# here takes a single `pdfium_annot` and makes ONE PDFium call.
# The list-of-annots reader sits in `R/annotations.R`; the bulk
# tibble shape is rebuilt by walking the list of handles.

#' Validate that `annot` is an open `pdfium_annot`.
#' @keywords internal
#' @noRd
check_annot <- function(annot, arg = "annot") {
  checkmate::assert_class(annot, "pdfium_annot", .var.name = arg)
  if (!is_open(annot)) {
    stop("Annotation handle has been closed.", call. = FALSE)
  }
  invisible(annot)
}

#' Annotation subtype (string)
#'
#' Returns the annotation's subtype as a short name (`"text"`,
#' `"link"`, `"freetext"`, …). Wraps `FPDFAnnot_GetSubtype`.
#'
#' @param annot A `pdfium_annot` handle from [pdf_annotations()].
#' @return Character scalar; one of the 29 PDFium annotation
#'   subtype names, or `"unknown"`.
#' @export
pdf_annot_subtype <- function(annot) {
  check_annot(annot)
  annotation_subtype_name(cpp_annot_subtype_code(annot$ptr))
}

#' Annotation subtype code (integer enum)
#'
#' Returns the raw `FPDF_ANNOT_*` integer for the annotation. Useful
#' when round-tripping into writers that take the enum directly.
#'
#' @inheritParams pdf_annot_subtype
#' @return Integer in `0..28`.
#' @export
pdf_annot_subtype_code <- function(annot) {
  check_annot(annot)
  cpp_annot_subtype_code(annot$ptr)
}

#' Annotation flag bitmask
#'
#' Returns the raw `/F` flag bitmask. Use [pdf_annot_flags_decoded()]
#' for the named-logical decomposition. Wraps `FPDFAnnot_GetFlags`.
#'
#' @inheritParams pdf_annot_subtype
#' @return Integer scalar.
#' @export
pdf_annot_flags <- function(annot) {
  check_annot(annot)
  cpp_annot_flags(annot$ptr)
}

#' Annotation flags decoded as named logicals
#'
#' Returns the six documented PDF annotation flag bits (Table 165 in
#' the PDF spec) as a named logical vector:
#' `is_invisible`, `is_hidden`, `is_print`, `is_no_view`,
#' `is_read_only`, `is_locked`. Computed from
#' [pdf_annot_flags()].
#'
#' @inheritParams pdf_annot_subtype
#' @return Named logical of length 6.
#' @export
pdf_annot_flags_decoded <- function(annot) {
  flags <- pdf_annot_flags(annot)
  vapply(
    names(.pdfium_annot_flag_bits),
    function(bit_name) {
      annot_flag_decode(flags, .pdfium_annot_flag_bits[[bit_name]])
    },
    logical(1L)
  )
}

#' Annotation bounding rectangle
#'
#' Returns the annotation's `/Rect` as a named numeric vector
#' (`bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top`)
#' in PDF user-space points. Wraps `FPDFAnnot_GetRect`. All four
#' values are `NA` when the annotation has no rectangle.
#'
#' @inheritParams pdf_annot_subtype
#' @return Named numeric of length 4.
#' @export
pdf_annot_bounds <- function(annot) {
  check_annot(annot)
  cpp_annot_bounds(annot$ptr)
}

#' Annotation `/Contents` text
#'
#' Returns the annotation's `/Contents` body text (UTF-8). Empty
#' string if absent.
#'
#' @inheritParams pdf_annot_subtype
#' @return Character scalar.
#' @export
pdf_annot_contents <- function(annot) {
  check_annot(annot)
  cpp_annot_string_value(annot$ptr, "Contents")
}

#' Annotation `/T` title (author) text
#'
#' Returns the annotation's `/T` title (commonly the author name).
#'
#' @inheritParams pdf_annot_subtype
#' @return Character scalar.
#' @export
pdf_annot_title <- function(annot) {
  check_annot(annot)
  cpp_annot_string_value(annot$ptr, "T")
}

#' Annotation `/Subj` subject text
#'
#' Returns the annotation's `/Subj` subject string.
#'
#' @inheritParams pdf_annot_subtype
#' @return Character scalar.
#' @export
pdf_annot_subject <- function(annot) {
  check_annot(annot)
  cpp_annot_string_value(annot$ptr, "Subj")
}

#' Annotation `/C` colour (RGBA, 0..1)
#'
#' Returns the four colour channels as 0..1 doubles. `NA` if the
#' annotation has no `/C`.
#'
#' @inheritParams pdf_annot_subtype
#' @return Named numeric of length 4 (`red`, `green`, `blue`,
#'   `alpha`).
#' @seealso [pdf_annot_interior_color()] for `/IC`.
#' @export
pdf_annot_color <- function(annot) {
  check_annot(annot)
  cpp_annot_color(annot$ptr, interior = FALSE)
}

#' Annotation `/IC` interior colour (RGBA, 0..1)
#'
#' Returns the annotation's interior colour (used by line / square
#' / circle / polygon subtypes). 0..1 doubles; `NA` if absent.
#'
#' @inheritParams pdf_annot_subtype
#' @return Named numeric of length 4.
#' @export
pdf_annot_interior_color <- function(annot) {
  check_annot(annot)
  cpp_annot_color(annot$ptr, interior = TRUE)
}

#' Annotation border width
#'
#' Returns the stroke border width from `/Border` or `/BS`.
#'
#' @inheritParams pdf_annot_subtype
#' @return Numeric scalar; `NA` if no border.
#' @export
pdf_annot_border_width <- function(annot) {
  check_annot(annot)
  cpp_annot_border(annot$ptr)
}

#' Annotation font size (FreeText / Widget subtypes)
#'
#' Returns the text-fill font size from the annotation's `/DA`
#' (default appearance string). Meaningful for FreeText / Widget
#' subtypes; `NA` for others.
#'
#' @inheritParams pdf_annot_subtype
#' @return Numeric scalar; `NA` when the subtype doesn't carry text.
#' @export
pdf_annot_font_size <- function(annot) {
  check_annot(annot)
  cpp_annot_font_size(annot$ptr, annot$page$doc$ptr)
}

#' Annotation font colour (RGB, 0..1)
#'
#' Returns the text-fill colour from the annotation's `/DA`. Three
#' channels in 0..1; `NA` when no colour is set.
#'
#' @inheritParams pdf_annot_subtype
#' @return Named numeric of length 3 (`red`, `green`, `blue`).
#' @export
pdf_annot_font_color <- function(annot) {
  check_annot(annot)
  cpp_annot_font_color(annot$ptr, annot$page$doc$ptr)
}

#' Construct a `pdfium_annot` handle for one annotation
#'
#' Looks up the annotation at `annotation_index` on `page` and
#' returns a handle. Wraps `FPDFPage_GetAnnot`.
#'
#' Most callers don't need this directly — [pdf_annotations()]
#' returns the full list of handles. `pdf_annot_at()` is the
#' targeted lookup, useful when you have an index from a tibble row.
#'
#' @param page A `pdfium_page` or `pdfium_doc`.
#' @param annotation_index One-based annotation index on the page.
#' @param page_num One-based page index (only used when `page` is a
#'   `pdfium_doc`).
#' @return A `pdfium_annot` handle.
#' @export
pdf_annot_at <- function(page, annotation_index, page_num = 1L) {
  checkmate::assert_count(annotation_index, positive = TRUE)
  # Same lifetime contract as pdf_annotations(): the returned annot
  # holds the page in its `prot` slot, so we must NOT defer-close
  # the transient page.
  page <- as_open_page(page, page_num, defer_close = FALSE)
  n <- cpp_annot_count(page$ptr)
  if (annotation_index > n) {
    stop(sprintf(
      "`annotation_index` (%d) exceeds the page's annotation count (%d).",
      annotation_index, n
    ), call. = FALSE)
  }
  ptr <- cpp_annot_get(page$ptr, as.integer(annotation_index - 1L))
  new_pdfium_annot(ptr, page, annotation_index)
}

#' Coerce input to a `pdfium_annot_list`
#'
#' Reverse companion to [as_tibble.pdfium_annot_list()]: takes
#' either an existing list of `pdfium_annot` handles or a tibble
#' produced by `as_tibble()` and returns a `pdfium_annot_list`.
#'
#' @param x Either a `pdfium_annot_list`, a list of `pdfium_annot`
#'   handles, or a tibble with a `handle` list-column.
#' @return A `pdfium_annot_list`.
#' @export
as_pdfium_annot_list <- function(x) {
  if (inherits(x, "pdfium_annot_list")) return(x)
  if (is.list(x) && length(x) > 0L &&
      all(vapply(x, inherits, logical(1L), "pdfium_annot"))) {
    source_page <- x[[1L]]$page
    return(new_pdfium_annot_list(x, source_page))
  }
  if (tibble::is_tibble(x) && "handle" %in% names(x)) {
    handles <- x$handle
    if (length(handles) == 0L) {
      stop("Cannot rebuild a `pdfium_annot_list` from a zero-row ",
           "tibble (source page unknown).", call. = FALSE)
    }
    source_page <- x$source[[1L]]
    return(new_pdfium_annot_list(handles, source_page))
  }
  stop("`x` must be a `pdfium_annot_list`, a list of `pdfium_annot`, ",
       "or a tibble produced by `as_tibble(pdf_annotations(page))`.",
       call. = FALSE)
}
