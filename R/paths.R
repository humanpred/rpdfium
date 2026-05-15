# PDFium's FPDFPathSegment_GetType return values, by code:
#   FPDF_SEGMENT_UNKNOWN  = -1
#   FPDF_SEGMENT_LINETO   =  0
#   FPDF_SEGMENT_BEZIERTO =  1
#   FPDF_SEGMENT_MOVETO   =  2
# We keep the lookup data-driven so future PDFium additions can be
# added by extending the table rather than touching the loop.
.pdfium_segment_type_names <- c(
  "lineto",   # 0  FPDF_SEGMENT_LINETO
  "bezierto", # 1  FPDF_SEGMENT_BEZIERTO
  "moveto"    # 2  FPDF_SEGMENT_MOVETO
)

# Internal: convert a FPDF_SEGMENT_* integer code to its short name.
# Returns "unknown" for negative or out-of-range codes so the public
# tibble stays well-typed against any future PDFium enum additions.
pdfium_segment_type_name <- function(codes) {
  codes <- as.integer(codes)
  out <- rep("unknown", length(codes))
  hit <- codes >= 0L & codes < length(.pdfium_segment_type_names)
  out[hit] <- .pdfium_segment_type_names[codes[hit] + 1L]
  out
}

#' Path segments of a path page-object
#'
#' Returns one row per segment of the path. Segments are emitted in
#' the same order they appear in the page's content stream, which is
#' the same order PDFium's rendering pipeline consumes. The result is
#' suitable for plotting the geometry or for downstream coordinate
#' analysis.
#'
#' Each row carries:
#'
#' * `index` - 1-based segment index within this path
#' * `type` - `"moveto"`, `"lineto"`, `"bezierto"`, or `"unknown"`
#' * `x`, `y` - the segment's anchor point in PDF points
#' * `close` - `TRUE` if this segment closes the current subpath
#'   (PDFium's `h` operator equivalent)
#'
#' **Known limitation:** PDFium's segment readout API exposes only the
#' endpoint of a `bezierto` segment, not its two control points.
#' Recovering control points requires content-stream parsing and is
#' deferred. For now, `bezierto` rows show the curve's endpoint; the
#' control-point information is lost. See
#' `docs/pdfium-api-review.md` for the full discussion.
#'
#' @param obj A `pdfium_obj` of type `"path"` (from
#'   [pdf_page_objects()]).
#' @return A tibble with the columns described above. An empty path
#'   returns a 0-row tibble of the same shape.
#'
#' @seealso [pdf_page_objects()], [pdf_obj_bounds()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
#'   pdf_path_segments(path_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_path_segments <- function(obj) {
  if (!inherits(obj, "pdfium_obj")) {
    stop("`obj` must be a `pdfium_obj` (from `pdf_page_objects()`).",
         call. = FALSE)
  }
  if (!is_open(obj)) {
    stop("Parent page has been closed; object handle is no longer valid.",
         call. = FALSE)
  }
  if (!identical(obj$type, "path")) {
    stop("`obj` must be a path-type pdfium_obj; got type \"",
         obj$type, "\".", call. = FALSE)
  }

  raw <- cpp_path_segments(obj$ptr)
  tibble::tibble(
    index = seq_along(raw$type),
    type  = pdfium_segment_type_name(raw$type),
    x     = raw$x,
    y     = raw$y,
    close = raw$close
  )
}
