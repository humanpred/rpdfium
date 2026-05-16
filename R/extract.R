#' Extract all path geometry on a page into a single tibble
#'
#' One-call helper that opens a document (or accepts an already-open
#' one), enumerates every path object on the requested page, and
#' returns a tibble with one row per path segment carrying both the
#' geometry and the containing path's stroke / fill style and
#' bounding box. This is the function `kmextract` consumes via the
#' `pdfium_native` backend.
#'
#' ## Returned tibble
#'
#' Each row describes one path-segment operator (a `moveto`,
#' `lineto`, or `bezierto`), in the order PDFium emits them:
#'
#' Path identity & segment geometry:
#'
#' * `path_index` - 1-based index of the parent path object on the
#'   page
#' * `segment_index` - 1-based segment index within the path
#' * `segment_type` - `"moveto"`, `"lineto"`, `"bezierto"`, or
#'   `"unknown"`
#' * `x`, `y` - the segment's anchor / endpoint in PDF points
#' * `close_figure` - logical, segment closes the current subpath
#'
#' Style (constant across all rows of one path):
#'
#' * `stroke_red`, `stroke_green`, `stroke_blue`, `stroke_alpha` -
#'   0-255 channels; `NA` if no stroke
#' * `stroke_width` - PDF points; `NA` if no stroke
#' * `fill_red`, `fill_green`, `fill_blue`, `fill_alpha` -
#'   0-255 channels; `NA` if no fill
#'
#' Path bounding box (constant across rows of one path):
#'
#' * `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` -
#'   PDF points
#'
#' ## Attributes
#'
#' * `page_size` - named numeric `c(width, height)` of the page in
#'   PDF points, from [pdf_page_size()]
#' * `page_rotation` - integer in `{0, 90, 180, 270}`, from
#'   [pdf_page_rotation()]
#' * `text_runs` - tibble with one row per text object on the page,
#'   the output of [pdf_text_runs()].
#'
#' ## Known limitations
#'
#' * Bezier control points are not exposed - only segment endpoints.
#'   PDFium does not expose them through its public C API; see
#'   `dev/decisions/ADR-009-defer-bezier-controls.md`.
#'
#' @param doc Either a character scalar path to a PDF file, or an
#'   already-open `pdfium_doc` returned by [pdf_open()]. When `doc`
#'   is a character path the document is opened and closed
#'   internally.
#' @param page_num One-based page index (default `1`).
#' @return A tibble with the schema described above.
#'
#' @seealso [pdf_path_segments()], [pdf_path_stroke()],
#'   [pdf_path_fill()], [pdf_obj_bounds()]
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   paths <- pdf_extract_paths(fixture, page_num = 1)
#'   head(paths)
#'   attr(paths, "page_size")
#'   attr(paths, "text_runs")
#' }
#' @export
pdf_extract_paths <- function(doc, page_num = 1L, password = NULL) {
  if (inherits(doc, "pdfium_doc")) {
    if (!is_open(doc)) stop("Document has been closed.", call. = FALSE)
  } else {
    doc <- pdf_open(doc, password = password)
    on.exit(pdf_close(doc), add = TRUE)
  }

  page_obj <- pdf_load_page(doc, page_num)
  on.exit(pdf_close_page(page_obj), add = TRUE, after = FALSE)

  page_size <- pdf_page_size(page_obj)
  page_rot  <- pdf_page_rotation(page_obj)

  objs <- pdf_page_objects(page_obj)
  paths <- which(vapply(objs, function(o) o$type == "path", logical(1)))

  # An empty-tibble template heads the rbind so the result has the
  # documented schema even when the page has zero paths. `lapply`
  # over an empty index vector returns `list()`, giving
  # `do.call(rbind, list(empty))` -> the empty template, with no
  # separate code branch to test.
  out <- do.call(rbind, c(
    list(empty_paths_tibble()),
    lapply(paths, function(i) one_path_rows(objs[[i]], i))
  ))
  # Text runs use the batched cpp_page_text_runs path under
  # pdf_text_runs(); one FPDFText_LoadPage/ClosePage cycle per page
  # instead of one per text object.
  text_runs <- pdf_text_runs(page_obj)

  attr(out, "page_size") <- page_size
  attr(out, "page_rotation") <- page_rot
  attr(out, "text_runs") <- text_runs
  out
}

# Internal: shape of an empty paths tibble (used as the zero-row
# template for both empty pages and rbind base).
empty_paths_tibble <- function() {
  tibble::tibble(
    path_index    = integer(),
    segment_index = integer(),
    segment_type  = character(),
    x             = double(),
    y             = double(),
    close_figure  = logical(),
    stroke_red    = double(),
    stroke_green  = double(),
    stroke_blue   = double(),
    stroke_alpha  = double(),
    stroke_width  = double(),
    fill_red      = double(),
    fill_green    = double(),
    fill_blue     = double(),
    fill_alpha    = double(),
    bounds_left   = double(),
    bounds_bottom = double(),
    bounds_right  = double(),
    bounds_top    = double()
  )
}

# Internal: shape of an empty text_runs tibble (attribute on the
# returned object).
empty_text_runs_tibble <- function() {
  tibble::tibble(
    text_index    = integer(),
    bounds_left   = double(),
    bounds_bottom = double(),
    bounds_right  = double(),
    bounds_top    = double(),
    font_size     = double(),
    text          = character()
  )
}

# Internal: build the per-segment rows for one path object,
# replicating the path-level style and bounds across each row.
one_path_rows <- function(obj, path_index) {
  segs   <- pdf_path_segments(obj)
  stroke <- pdf_path_stroke(obj)
  fill   <- pdf_path_fill(obj)
  bnds   <- pdf_obj_bounds(obj)

  n <- nrow(segs)
  tibble::tibble(
    path_index    = rep(path_index, n),
    segment_index = segs$segment_index,
    segment_type  = segs$segment_type,
    x             = segs$x,
    y             = segs$y,
    close_figure  = segs$close_figure,
    stroke_red    = rep(stroke[["red"]],   n),
    stroke_green  = rep(stroke[["green"]], n),
    stroke_blue   = rep(stroke[["blue"]],  n),
    stroke_alpha  = rep(stroke[["alpha"]], n),
    stroke_width  = rep(stroke[["width"]], n),
    fill_red      = rep(fill[["red"]],     n),
    fill_green    = rep(fill[["green"]],   n),
    fill_blue     = rep(fill[["blue"]],    n),
    fill_alpha    = rep(fill[["alpha"]],   n),
    bounds_left   = rep(bnds[["left"]],    n),
    bounds_bottom = rep(bnds[["bottom"]],  n),
    bounds_right  = rep(bnds[["right"]],   n),
    bounds_top    = rep(bnds[["top"]],     n)
  )
}

## one_text_row() removed - pdf_extract_paths() now delegates to the
## batched pdf_text_runs() implementation, which shares one
## FPDFText_LoadPage / FPDFText_ClosePage cycle across every text
## object on the page rather than paying the cost per-object.
