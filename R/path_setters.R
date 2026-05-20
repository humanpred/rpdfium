# Path-geometry appenders (Phase 4 of the v0.1.0 writer surface).
#
# PDFium exposes only append-style mutation on existing path
# page-objects (`FPDFPath_MoveTo`, `_LineTo`, `_BezierTo`, `_Close`).
# There is NO public segment-removal or segment-replacement API.
# Callers wanting to "rebuild" a path must compose this phase's
# appenders with Phase 5's `pdf_path_new()` + `pdf_obj_remove()`:
# create a fresh path with the new geometry, then remove the
# original.
#
# Each function follows the ADR-018 setter convention:
#   * `obj` is a `pdfium_obj` of type "path" whose parent doc is
#     read-write.
#   * checkmate validates the numeric inputs.
#   * On success the parent page is marked dirty and the parent
#     doc is invisibly returned for chaining.
#   * On failure (PDFium returns FALSE) the wrapper raises a clean
#     R error via the same `expect_setter_ok` helper Phase 3's
#     setters use.

#' Append a MoveTo command to a path object
#'
#' Wraps `FPDFPath_MoveTo`. Moves the path's "current point" to
#' `(x, y)` without drawing — useful as the start of a new subpath
#' or to leave a gap between strokes within a single path object.
#'
#' @param obj A `pdfium_obj` of type `"path"`. Parent doc must be
#'   readwrite.
#' @param x,y Numeric scalars in PDF user-space points (origin at
#'   the page's bottom-left).
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_line_to()], [pdf_path_bezier_to()],
#'   [pdf_path_close()], [pdf_path_append()].
#' @export
pdf_path_move_to <- function(obj, x, y) {
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  expect_setter_ok(
    cpp_path_move_to(obj$ptr, as.numeric(x), as.numeric(y)),
    "FPDFPath_MoveTo"
  )
  finalize_obj_setter(ctx)
}

#' Append a LineTo command to a path object
#'
#' Wraps `FPDFPath_LineTo`. Draws a straight line from the path's
#' current point to `(x, y)`, advancing the current point.
#'
#' @inheritParams pdf_path_move_to
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_move_to()], [pdf_path_bezier_to()],
#'   [pdf_path_close()], [pdf_path_append()].
#' @export
pdf_path_line_to <- function(obj, x, y) {
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  expect_setter_ok(
    cpp_path_line_to(obj$ptr, as.numeric(x), as.numeric(y)),
    "FPDFPath_LineTo"
  )
  finalize_obj_setter(ctx)
}

#' Append a cubic Bezier curve to a path object
#'
#' Wraps `FPDFPath_BezierTo`. Draws a cubic Bezier curve from the
#' path's current point to `(x3, y3)`, with control points
#' `(x1, y1)` and `(x2, y2)`. The PDF operator emitted is `c`.
#'
#' @inheritParams pdf_path_move_to
#' @param x1,y1 First control point.
#' @param x2,y2 Second control point.
#' @param x3,y3 Curve endpoint (becomes the new current point).
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_move_to()], [pdf_path_line_to()],
#'   [pdf_path_close()], [pdf_path_append()].
#' @export
pdf_path_bezier_to <- function(obj, x1, y1, x2, y2, x3, y3) {
  checkmate::assert_number(x1, finite = TRUE)
  checkmate::assert_number(y1, finite = TRUE)
  checkmate::assert_number(x2, finite = TRUE)
  checkmate::assert_number(y2, finite = TRUE)
  checkmate::assert_number(x3, finite = TRUE)
  checkmate::assert_number(y3, finite = TRUE)
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  expect_setter_ok(
    cpp_path_bezier_to(
      obj$ptr,
      as.numeric(x1), as.numeric(y1),
      as.numeric(x2), as.numeric(y2),
      as.numeric(x3), as.numeric(y3)
    ),
    "FPDFPath_BezierTo"
  )
  finalize_obj_setter(ctx)
}

#' Close the current subpath of a path object
#'
#' Wraps `FPDFPath_Close`. Draws a straight line from the current
#' point back to the most recent `MoveTo` and marks the subpath as
#' closed (so stroking joins the ends correctly and filling
#' respects the closed region).
#'
#' @inheritParams pdf_path_move_to
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_move_to()], [pdf_path_line_to()],
#'   [pdf_path_bezier_to()], [pdf_path_append()].
#' @export
pdf_path_close <- function(obj) {
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  expect_setter_ok(cpp_path_close(obj$ptr), "FPDFPath_Close")
  finalize_obj_setter(ctx)
}

#' Append a sequence of path segments in one call
#'
#' Convenience wrapper that takes a tibble in the shape
#' [pdf_path_segments()] returns and replays it as a series of
#' appender calls on `obj`. Useful when you've read a path with
#' [pdf_path_segments()], edited the rows in R, and want to append
#' the modified geometry to a fresh path object.
#'
#' Segment dispatch by the `segment_type` column:
#'
#' * `"moveto"` → [pdf_path_move_to()] with `(x, y)`.
#' * `"lineto"` → [pdf_path_line_to()] with `(x, y)`.
#' * `"bezierto"` → cubic Bezier. PDFium's reader surfaces each
#'   cubic curve as **three** consecutive `bezierto` rows (two
#'   control points then the endpoint); this wrapper buffers two
#'   rows and emits a single [pdf_path_bezier_to()] call on the
#'   third.
#'
#' Any row whose `close_figure` column is `TRUE` triggers a
#' [pdf_path_close()] after its segment.
#'
#' @inheritParams pdf_path_move_to
#' @param segments A tibble with at minimum the columns
#'   `segment_type` (character), `x`, `y` (numeric), and optionally
#'   `close_figure` (logical). Matches the [pdf_path_segments()]
#'   output exactly so a reader → edit → writer round-trip is a
#'   one-liner.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_segments()].
#' @export
pdf_path_append <- function(obj, segments) {
  checkmate::assert_data_frame(segments, min.rows = 0L)
  checkmate::assert_subset(c("segment_type", "x", "y"),
                            names(segments))
  checkmate::assert_character(segments$segment_type,
                                any.missing = FALSE)
  checkmate::assert_numeric(segments$x, any.missing = FALSE,
                              finite = TRUE)
  checkmate::assert_numeric(segments$y, any.missing = FALSE,
                              finite = TRUE)
  has_close <- "close_figure" %in% names(segments)
  if (has_close) {
    checkmate::assert_logical(segments$close_figure,
                                any.missing = FALSE)
  }
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  bezier_buffer <- list()
  for (i in seq_len(nrow(segments))) {
    type <- segments$segment_type[[i]]
    x <- segments$x[[i]]
    y <- segments$y[[i]]
    if (type == "moveto") {
      if (length(bezier_buffer) != 0L) {
        stop(incomplete_bezier_msg(length(bezier_buffer)),
             call. = FALSE)
      }
      expect_setter_ok(cpp_path_move_to(obj$ptr, x, y),
                        "FPDFPath_MoveTo")
    } else if (type == "lineto") {
      if (length(bezier_buffer) != 0L) {
        stop(incomplete_bezier_msg(length(bezier_buffer)),
             call. = FALSE)
      }
      expect_setter_ok(cpp_path_line_to(obj$ptr, x, y),
                        "FPDFPath_LineTo")
    } else if (type == "bezierto") {
      bezier_buffer[[length(bezier_buffer) + 1L]] <- c(x, y)
      if (length(bezier_buffer) == 3L) {
        expect_setter_ok(
          cpp_path_bezier_to(
            obj$ptr,
            bezier_buffer[[1L]][1L], bezier_buffer[[1L]][2L],
            bezier_buffer[[2L]][1L], bezier_buffer[[2L]][2L],
            bezier_buffer[[3L]][1L], bezier_buffer[[3L]][2L]
          ),
          "FPDFPath_BezierTo"
        )
        bezier_buffer <- list()
      }
    } else {
      stop(sprintf("Unknown path segment type: %s", type),
           call. = FALSE)
    }
    if (has_close && isTRUE(segments$close_figure[[i]])) {
      expect_setter_ok(cpp_path_close(obj$ptr), "FPDFPath_Close")
    }
  }
  if (length(bezier_buffer) > 0L) {
    stop(incomplete_bezier_msg(length(bezier_buffer)),
         call. = FALSE)
  }
  finalize_obj_setter(ctx)
}

# Internal: build the error message for a partial bezier triplet.
incomplete_bezier_msg <- function(got) {
  sprintf(
    paste0(
      "Incomplete bezierto triplet in `segments` (got %d of 3 ",
      "expected points). Cubic Beziers in PDFium's segment shape ",
      "come as three consecutive `bezierto` rows: two control ",
      "points then the endpoint."
    ),
    got
  )
}
