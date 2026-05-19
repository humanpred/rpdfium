# Clip-path readout for page objects. Wraps the four PDFium
# `FPDFClipPath_*` functions plus `FPDFPageObj_GetClipPath`, with
# a small `pdfium_clip_path` S3 class for handle hygiene.

# Internal constructor. The clip path's lifetime is owned by the
# parent page; the externalptr already carries the page pointer in
# its `prot` slot (see cpp_obj_get_clip_path), but we store the
# pdfium_page on the R-side wrapper too so format/print can show
# the containment chain.
new_pdfium_clip_path <- function(ptr, page, source_obj_index, n_paths) {
  stopifnot(
    typeof(ptr) == "externalptr",
    inherits(page, "pdfium_page"),
    is.numeric(source_obj_index), length(source_obj_index) == 1L,
    is.numeric(n_paths), length(n_paths) == 1L
  )
  structure(
    list(
      ptr = ptr, page = page,
      source_obj_index = as.integer(source_obj_index),
      n_paths = as.integer(n_paths)
    ),
    class = c("pdfium_clip_path", "pdfium_handle")
  )
}

#' @export
format.pdfium_clip_path <- function(x, ...) {
  state <- if (is_open(x$page)) "open" else "closed"
  sprintf(
    "<pdfium_clip_path [%s] %d sub-path(s) from obj %d on page %d>",
    state, x$n_paths, x$source_obj_index, x$page$index
  )
}

#' @export
print.pdfium_clip_path <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

#' Get the clip path attached to a page object
#'
#' A PDF clip path defines the geometric region inside which a page
#' object is allowed to draw. Wraps `FPDFPageObj_GetClipPath`. Most
#' page objects have no clip path; this function returns `NULL` for
#' those.
#'
#' PDFium returns a non-NULL clip handle even for objects whose
#' clip is "empty" (the underlying `CPDF_ClipPath` exists but has
#' no sub-paths attached). This wrapper normalizes that case to
#' `NULL` so callers only see clip-path objects with at least one
#' real sub-path.
#'
#' @param obj A `pdfium_obj` (from [pdf_page_objects()] or
#'   [pdf_form_objects()]).
#' @return A `pdfium_clip_path` object, or `NULL` when `obj` has no
#'   clip path or only an empty one.
#'
#' @seealso [pdf_clip_path_count()], [pdf_clip_path_segments()].
#' @examples
#' fixture <- system.file("extdata", "fixtures", "clip.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   page <- pdf_load_page(doc, 1L)
#'   objs <- pdf_page_objects(page)
#'   clipped <- Filter(function(o) !is.null(pdf_obj_clip_path(o)), objs)
#'   length(clipped)
#'   pdf_close_page(page)
#'   pdf_close(doc)
#' }
#' @export
pdf_obj_clip_path <- function(obj) {
  if (!inherits(obj, "pdfium_obj")) {
    stop("`obj` must be a `pdfium_obj` (from `pdf_page_objects()` ",
      "or `pdf_form_objects()`).",
      call. = FALSE
    )
  }
  if (!is_open(obj)) {
    stop("Parent page has been closed; the page object is no longer valid.",
      call. = FALSE
    )
  }
  ptr <- cpp_obj_get_clip_path(obj$ptr, obj$page$ptr)
  # FPDFPageObj_GetClipPath returns a handle for every page object
  # (it's a pointer to the obj's `m_ClipPath` member, which exists
  # even when empty), so this branch is defensive against future
  # PDFium changes that might start returning NULL.
  # nocov start
  if (is.null(ptr)) {
    return(NULL)
  }
  # nocov end
  n <- cpp_clip_path_count_paths(ptr)
  if (n == 0L) {
    return(NULL)
  }
  new_pdfium_clip_path(ptr, obj$page, obj$index, n)
}

#' Count sub-paths in a clip path
#'
#' Wraps `FPDFClipPath_CountPaths`. A clip path can consist of
#' multiple sub-paths (e.g. a union of rectangles); this returns
#' how many.
#'
#' @param clip_path A `pdfium_clip_path` from [pdf_obj_clip_path()].
#' @return Integer scalar.
#' @export
pdf_clip_path_count <- function(clip_path) {
  if (!inherits(clip_path, "pdfium_clip_path")) {
    stop("`clip_path` must be a `pdfium_clip_path` (from ",
      "`pdf_obj_clip_path()`).",
      call. = FALSE
    )
  }
  if (!is_open(clip_path$page)) {
    stop("Parent page has been closed; the clip path is no longer valid.",
      call. = FALSE
    )
  }
  cpp_clip_path_count_paths(clip_path$ptr)
}

#' Read all segments of a clip path as a tibble
#'
#' Returns a data frame describing every segment in every sub-path
#' of `clip_path`, ordered first by `path_index` and then by
#' `seg_index` within each sub-path. Mirrors the shape of
#' [pdf_path_segments()] but adds a `path_index` column for the
#' clip's outer level. Wraps `FPDFClipPath_CountPaths`,
#' `FPDFClipPath_CountPathSegments`, and
#' `FPDFClipPath_GetPathSegment`.
#'
#' Coordinates are in PDF user space (typically points, with the
#' origin at the page's bottom-left).
#'
#' @param clip_path A `pdfium_clip_path` from [pdf_obj_clip_path()].
#' @return A tibble with columns:
#'   * `path_index` integer - 1-based sub-path index within the clip
#'   * `segment_index` integer - 1-based segment index within its
#'     sub-path
#'   * `segment_type` character - `"moveto"`, `"lineto"`,
#'     `"bezierto"`, or `"unknown"`
#'   * `x`, `y` numeric - segment coordinates in PDF user space
#'   * `close_figure` logical - whether this segment closes its
#'     sub-path
#' @seealso [pdf_path_segments()] for the same shape applied to a
#'   regular page object's path.
#' @export
pdf_clip_path_segments <- function(clip_path) {
  if (!inherits(clip_path, "pdfium_clip_path")) {
    stop("`clip_path` must be a `pdfium_clip_path` (from ",
      "`pdf_obj_clip_path()`).",
      call. = FALSE
    )
  }
  if (!is_open(clip_path$page)) {
    stop("Parent page has been closed; the clip path is no longer valid.",
      call. = FALSE
    )
  }
  raw <- cpp_clip_path_segments_df(clip_path$ptr)
  # PDFium segment-type ints: 0 = LINETO, 1 = BEZIERTO, 2 = MOVETO.
  # See FPDF_SEGMENT_* in fpdf_edit.h. Match the labelling used by
  # pdf_path_segments() (see R/paths.R).
  type_map <- c("lineto", "bezierto", "moveto")
  type_chr <- ifelse(
    is.na(raw$seg_type) | raw$seg_type < 0L | raw$seg_type > 2L,
    "unknown",
    type_map[raw$seg_type + 1L]
  )
  tibble::tibble(
    path_index    = raw$path_index,
    segment_index = raw$seg_index,
    segment_type  = type_chr,
    x             = raw$x,
    y             = raw$y,
    close_figure  = raw$close_figure
  )
}
