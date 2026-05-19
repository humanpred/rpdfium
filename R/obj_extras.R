# Small additional page-object accessors added in the 0.1.0
# read-completion pass. Each thin-wraps one PDFium getter and returns
# a single fact about the page object.

.pdfium_line_caps <- c("butt", "round", "projecting_square")
.pdfium_line_joins <- c("miter", "round", "bevel")

# Internal: object-validator helper for the pdfium_obj wrappers below.
# Splits per-type checks from each public function so cyclocomp stays
# under the lintr limit.
check_pdfium_obj <- function(obj, allowed_types = NULL) {
  if (!inherits(obj, "pdfium_obj")) {
    stop("`obj` must be a `pdfium_obj` (from `pdf_page_objects()`).",
      call. = FALSE
    )
  }
  if (!is_open(obj)) {
    stop("Parent page has been closed; object handle is no longer valid.",
      call. = FALSE
    )
  }
  if (!is.null(allowed_types) && !(obj$type %in% allowed_types)) {
    stop(sprintf(
      "`obj` must be one of {%s}; got type \"%s\".",
      paste(allowed_types, collapse = ", "), obj$type
    ), call. = FALSE)
  }
  invisible(obj)
}

#' Stroke line-cap style of a path page-object
#'
#' Returns the PDF line-cap style applied to a path's stroke. Maps to
#' the `LC` operand in the page content stream and corresponds to
#' PDFium's `FPDFPageObj_GetLineCap`.
#'
#' @param obj A `pdfium_obj` of type `"path"` from
#'   [pdf_page_objects()].
#' @return Character scalar; one of `"butt"` (square cap aligned with
#'   the stroke endpoint, the PDF default), `"round"` (semicircular
#'   extension past the endpoint), or `"projecting_square"` (square
#'   cap extending one half-line-width past the endpoint).
#' @seealso [pdf_path_line_join()], [pdf_path_stroke()].
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
#'   pdf_path_line_cap(path_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_path_line_cap <- function(obj) {
  check_pdfium_obj(obj, allowed_types = "path")
  code <- cpp_obj_line_cap(obj$ptr)
  idx <- code + 1L
  # nocov start — PDFium's line-cap enum is 0/1/2; the "unknown"
  # fallback is defensive against a future enum extension.
  if (idx < 1L || idx > length(.pdfium_line_caps)) {
    return("unknown")
  }
  # nocov end
  .pdfium_line_caps[[idx]]
}

#' Stroke line-join style of a path page-object
#'
#' Returns the PDF line-join style applied at corners along a stroked
#' path. Maps to the `LJ` operand and corresponds to PDFium's
#' `FPDFPageObj_GetLineJoin`.
#'
#' @param obj A `pdfium_obj` of type `"path"` from
#'   [pdf_page_objects()].
#' @return Character scalar; one of `"miter"` (sharp pointed corner,
#'   the PDF default), `"round"` (circular arc at the corner), or
#'   `"bevel"` (flat corner).
#' @seealso [pdf_path_line_cap()], [pdf_path_stroke()].
#' @export
pdf_path_line_join <- function(obj) {
  check_pdfium_obj(obj, allowed_types = "path")
  code <- cpp_obj_line_join(obj$ptr)
  idx <- code + 1L
  # nocov start — defensive: PDFium line-join enum is 0/1/2.
  if (idx < 1L || idx > length(.pdfium_line_joins)) {
    return("unknown")
  }
  # nocov end
  .pdfium_line_joins[[idx]]
}

#' Does a page object use alpha blending?
#'
#' Returns `TRUE` when PDFium reports that the page object contributes
#' any alpha (a fill or stroke colour with alpha < 255, an embedded
#' image with an alpha or soft-mask channel, a Form XObject containing
#' transparency, etc.). Wraps `FPDFPageObj_HasTransparency`.
#'
#' @param obj A `pdfium_obj` of any type from [pdf_page_objects()].
#' @return Logical scalar.
#' @export
pdf_obj_has_transparency <- function(obj) {
  check_pdfium_obj(obj)
  cpp_obj_has_transparency(obj$ptr)
}

#' Active flag of a page object
#'
#' Returns the PDFium "is active" flag. Inactive page objects are
#' still enumerated by [pdf_page_objects()] but PDFium skips them
#' when rendering or measuring extents. Wraps
#' `FPDFPageObj_GetIsActive`.
#'
#' @param obj A `pdfium_obj` of any type from [pdf_page_objects()].
#' @return Logical scalar (`TRUE` / `FALSE`), or `NA` when PDFium
#'   reports failure (very rare).
#' @export
pdf_obj_is_active <- function(obj) {
  check_pdfium_obj(obj)
  cpp_obj_is_active(obj$ptr)
}

#' Rotated bounding quadpoints of a page object
#'
#' For objects that have been rotated by a transformation matrix
#' (e.g. text drawn at an angle, or a placed image with a rotated
#' Form XObject CTM), the axis-aligned bounding box from
#' [pdf_obj_bounds()] is loose. `pdf_obj_rotated_bounds()` returns
#' the tighter rotated rectangle as four corner points. Wraps
#' `FPDFPageObj_GetRotatedBounds`.
#'
#' The four corners are returned in the order PDFium reports them:
#' `(x1, y1)` is lower-left, `(x2, y2)` lower-right, `(x3, y3)`
#' upper-right, `(x4, y4)` upper-left, where "lower" / "upper" are
#' relative to the rotated rectangle's own local axes (not the page).
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()].
#' @return A length-8 named numeric vector
#'   `c(x1, y1, x2, y2, x3, y3, x4, y4)` in PDF user-space points,
#'   or all-`NA` when PDFium reports no bounds for this object.
#' @seealso [pdf_obj_bounds()] for the cheaper axis-aligned box.
#' @export
pdf_obj_rotated_bounds <- function(obj) {
  check_pdfium_obj(obj)
  cpp_obj_rotated_bounds(obj$ptr)
}

#' Content marks attached to a page object
#'
#' Returns one tibble row per *content mark* on the page object — the
#' tagged-PDF mechanism that links a piece of page content (a path,
#' a text run, an image, ...) to a structure element in
#' [pdf_structure_tree()]. Wraps `FPDFPageObj_CountMarks`,
#' `FPDFPageObj_GetMark`, `FPDFPageObjMark_GetName`,
#' `_CountParams`, `_GetParamKey`, `_GetParamValueType`, and the
#' `_GetParamIntValue` / `_GetParamStringValue` /
#' `_GetParamBlobValue` accessors.
#'
#' Each mark carries a *name* (typically the structural type or BDC
#' tag — e.g. `"P"`, `"Span"`, `"Artifact"`) and zero or more
#' parameters as key/value pairs. The most common parameter is
#' `MCID` (an integer linking the object to a structure tree
#' element's marked-content reference).
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()].
#' @return A tibble with columns:
#'   * `mark_index` integer - 1-based position in the object's mark
#'     stack.
#'   * `name` character - the mark name (BDC tag).
#'   * `params` list-column - a named list of the mark's parameter
#'     values. Values are typed in R: numeric for `FPDF_OBJECT_NUMBER`,
#'     character for `_STRING` / `_NAME`, raw vectors for blobs.
#'
#' Returns a 0-row tibble of the same schema when the object has no
#' marks (typical for content from untagged PDFs).
#' @seealso [pdf_structure_tree()] for the structure-tree side of
#'   the same linkage; [pdf_obj_type()].
#' @export
pdf_obj_marks <- function(obj) {
  check_pdfium_obj(obj)
  raw <- cpp_obj_marks_list(obj$ptr)
  n <- length(raw$name)
  if (n == 0L) {
    return(empty_obj_marks_tibble())
  }
  tibble::tibble(
    mark_index = seq_len(n),
    name       = as.character(raw$name),
    params     = raw$params
  )
}

empty_obj_marks_tibble <- function() {
  tibble::tibble(
    mark_index = integer(),
    name       = character(),
    params     = list()
  )
}
