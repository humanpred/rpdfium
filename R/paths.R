# PDFium FPDFPathSegment_GetType codes: UNKNOWN is -1, LINETO is 0,
# BEZIERTO is 1, MOVETO is 2. The lookup vector below is indexed by
# code + 1; future additions extend the vector without touching the
# segment loop.
.pdfium_segment_type_names <- c(
  "lineto",
  "bezierto",
  "moveto"
)

# Internal: convert a FPDF_SEGMENT_* integer code to its short name.
pdfium_segment_type_name <- function(codes) {
  .pdfium_enum_name(codes, .pdfium_segment_type_names)
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
#' * `segment_index` - 1-based segment index within this path
#' * `segment_type` - `"moveto"`, `"lineto"`, `"bezierto"`, or
#'   `"unknown"`
#' * `x`, `y` - the segment's anchor point in PDF points
#' * `close_figure` - `TRUE` if this segment closes the current
#'   subpath (PDFium's `h` operator equivalent)
#'
#' **Known limitation:** PDFium's segment readout API exposes only the
#' endpoint of a `bezierto` segment, not its two control points. The
#' public C API offers no way to recover them; the limitation is
#' shared by pypdfium2, pdfium-rs, and pdfium-render. For now,
#' `bezierto` rows show the curve's endpoint; control-point
#' information is lost. See
#' `dev/decisions/ADR-009-defer-bezier-controls.md` for the
#' decision record.
#'
#' @param obj A `pdfium_obj` of type `"path"` (from
#'   [pdf_page_objects()]).
#' @return A tibble with the columns described above. An empty path
#'   returns a 0-row tibble of the same shape.
#'
#' @seealso [pdf_page_objects()], [pdf_obj_bounds()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
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
  obj <- check_path_obj(obj)
  raw <- cpp_path_segments(obj$ptr)
  tibble::tibble(
    segment_index = seq_along(raw$type),
    segment_type  = pdfium_segment_type_name(raw$type),
    x             = raw$x,
    y             = raw$y,
    close_figure  = raw$close
  )
}

# Internal: validate that `obj` is an open pdfium_obj of type "path".
# Returns the validated object so callers can chain.
check_path_obj <- function(obj) {
  check_pdfium_obj(obj, allowed_types = "path")
  obj
}

#' Stroke style of a path page-object
#'
#' Returns the RGBA stroke color and stroke width of `obj` as a flat
#' named numeric vector. Color channels are integers in `[0, 255]`;
#' width is in PDF points. When PDFium reports that the object has
#' no stroke set, every value is `NA`.
#'
#' The returned shape mirrors [pdf_path_fill()] (a flat named
#' vector). The downstream tibble columns in [pdf_extract_paths()]
#' (`stroke_red`, `stroke_green`, `stroke_blue`, `stroke_alpha`,
#' `stroke_width`) are built by prefixing the names of this vector.
#'
#' @param obj A `pdfium_obj` of type `"path"` (from
#'   [pdf_page_objects()]).
#' @return A named numeric vector with elements `red`, `green`,
#'   `blue`, `alpha` (0-255 channels) and `width` (PDF points).
#'   All-`NA` when no stroke is set.
#'
#' @seealso [pdf_path_fill()], [pdf_path_segments()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
#'   pdf_path_stroke(path_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_path_stroke <- function(obj) {
  obj <- check_path_obj(obj)
  col <- cpp_obj_stroke_color(obj$ptr)
  c(col, width = cpp_obj_stroke_width(obj$ptr))
}

#' Fill color of a path page-object
#'
#' Returns the RGBA fill color of `obj`. Channels are integers in
#' `[0, 255]`. When PDFium reports that the object has no fill set
#' (e.g. a stroke-only path), all four channels are `NA`.
#'
#' @param obj A `pdfium_obj` of type `"path"` (from
#'   [pdf_page_objects()]).
#' @return A named numeric vector `c(red, green, blue, alpha)` of
#'   0-255 channel values, or all-`NA` when no fill is set.
#'
#' @seealso [pdf_path_stroke()], [pdf_path_segments()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
#'   pdf_path_fill(path_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_path_fill <- function(obj) {
  obj <- check_path_obj(obj)
  cpp_obj_fill_color(obj$ptr)
}

#' Dash pattern of a path page-object
#'
#' Returns the dash array (in PDF points) and dash phase (offset
#' into the pattern, in points) attached to `obj`'s stroke. A solid
#' (un-dashed) path returns an empty `array` and phase `0`.
#'
#' A dash array of `c(3, 2)` for example means: draw 3 points, skip
#' 2 points, repeat. The phase shifts where in the pattern the
#' first segment starts.
#'
#' @param obj A `pdfium_obj` of type `"path"` (from
#'   [pdf_page_objects()]).
#' @return A named list with two elements:
#'   * `array` - numeric vector of dash lengths in PDF points;
#'     length-zero for solid lines.
#'   * `phase` - numeric scalar, the dash-pattern phase in points
#'     (typically `0`).
#'
#' @seealso [pdf_path_stroke()] for the stroke color and width.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
#'   pdf_path_dash(path_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_path_dash <- function(obj) {
  obj <- check_path_obj(obj)
  list(
    array = cpp_obj_dash_array(obj$ptr),
    phase = cpp_obj_dash_phase(obj$ptr)
  )
}

# PDFium FPDF_FILLMODE_* codes (fpdf_edit.h):
#   0 = NONE       (clip-only path; not painted)
#   1 = ALTERNATE  (even-odd fill rule)
#   2 = WINDING    (non-zero winding fill rule)
.pdfium_fill_mode_names <- c("none", "even_odd", "winding")

#' Path draw mode (fill rule + stroke flag)
#'
#' Returns whether a path object is stroked and which fill mode is
#' applied. A path can be:
#'
#' * Stroked only (`stroke = TRUE`, `fill_mode = "none"`).
#' * Filled with non-zero winding rule (`fill_mode = "winding"`).
#' * Filled with even-odd rule (`fill_mode = "even_odd"`).
#' * Both stroked and filled (`stroke = TRUE` + `fill_mode != "none"`).
#' * Invisible (`stroke = FALSE`, `fill_mode = "none"`) — used for
#'   clip-only paths.
#'
#' Wraps `FPDFPath_GetDrawMode`.
#'
#' @param obj A `pdfium_obj` of type `"path"`.
#' @return A named list with two elements:
#'   * `fill_mode` - one of `"none"`, `"even_odd"`, `"winding"`.
#'     `NA` if PDFium reports no draw-mode (rare; typically only on
#'     malformed paths).
#'   * `fill_mode_code` - the raw integer code (`0`, `1`, `2`) for
#'     round-tripping with v0.2.0 writers.
#'   * `stroke` - logical scalar; `TRUE` if the path is stroked.
#' @seealso [pdf_path_stroke()] for the stroke color/width;
#'   [pdf_path_fill()] for the fill color.
#' @export
pdf_path_draw_mode <- function(obj) {
  obj <- check_path_obj(obj)
  raw <- cpp_path_draw_mode(obj$ptr)
  list(
    fill_mode      = .pdfium_enum_name(raw$fill_mode_code,
                                       .pdfium_fill_mode_names,
                                       fallback = NA_character_),
    fill_mode_code = as.integer(raw$fill_mode_code),
    stroke         = as.logical(raw$stroke)
  )
}
