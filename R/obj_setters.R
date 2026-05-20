# Page-object styling setters (Phase 3 of the v0.1.0 writer surface).
# Each setter takes a `pdfium_obj` handle (the identity, per ADR-018),
# validates inputs through checkmate, calls the matching cpp_obj_set_*
# shim, marks the parent page dirty so pdf_save() / pdf_render_*() see
# the change, and returns the parent `pdfium_doc` invisibly for chaining.
#
# Naming + dispatch follow ADR-018:
#   * object-first naming (`pdf_obj_set_*` for general, `pdf_path_set_*`
#     for path-only, `pdf_text_set_*` for text-only).
#   * composite setters (stroke / fill) accept named partial updates;
#     the function reads the current state for any arg left NULL.
#   * color setters accept either 0-255 ints or 0-1 doubles; the
#     normalizer in `normalize_rgba()` auto-detects via max value.

# PDFium fill mode for FPDFPath_SetDrawMode. Indexed by code 0..2:
# code 0 is "none", code 1 is "even_odd" (the PDF spec's
# alternate / even-odd rule), code 2 is "winding". Mirrors
# `.pdfium_fill_mode_names` in R/paths.R; duplicated rather than
# referenced because R loads files alphabetically and obj_setters
# precedes paths.
.pdfium_fill_modes <- c("none", "even_odd", "winding")

# PDFium text render mode. Indexed 0..7; matches the bulk reader.
.pdfium_text_render_modes <- c(
  "fill", "stroke", "fill_stroke", "invisible",
  "fill_clip", "stroke_clip", "fill_stroke_clip", "clip"
)

# Allowed blend mode strings per PDFium's FPDFPageObj_SetBlendMode
# doc comment. The PDF spec also lists "Compatible" but PDFium
# accepts it silently; we omit it as it's the default and rarely
# useful from the writer side.
.pdfium_blend_modes <- c(
  "Color", "ColorBurn", "ColorDodge", "Darken", "Difference",
  "Exclusion", "HardLight", "Hue", "Lighten", "Luminosity",
  "Multiply", "Normal", "Overlay", "Saturation", "Screen",
  "SoftLight"
)

# Internal: validate that `obj`'s parent doc is read-write, return
# the doc + the dirty-page index for the caller.
assert_obj_writable <- function(obj, allowed_types = NULL,
                                 arg = "obj") {
  check_pdfium_obj(obj, allowed_types = allowed_types, arg = arg)
  doc <- obj$page$doc
  assert_readwrite(doc)
  list(doc = doc, page_index = obj$page$index)
}

# Internal: every PDFium setter returns a FPDF_BOOL — bubble FALSE
# up as a clean R error naming the operation. Marked nocov because
# PDFium setters return FALSE only on internal invariants the
# Phase-3 wrappers can't trip through valid arguments (we validate
# everything upstream); reaching this is a PDFium regression.
# nocov start
expect_setter_ok <- function(ok, what) {
  if (!isTRUE(ok)) {
    stop(sprintf("%s failed.", what), call. = FALSE)
  }
}
# nocov end

# Internal: hook for tracking after a setter. Marks the parent page
# dirty and returns the doc invisibly (ADR-018 §6 — every setter
# returns the doc for chaining).
finalize_obj_setter <- function(ctx) {
  mark_page_dirty(ctx$doc, ctx$page_index)
  invisible(ctx$doc)
}

# Internal: normalise a color spec to a length-4 numeric vector of
# 0-255 channel values (R, G, B, A). Accepts:
#   * length-3 or -4 numeric in [0, 255] (treated as 0-255 already)
#   * length-3 or -4 numeric in [0, 1]   (treated as 0-1 doubles)
# Auto-detection picks 0-1 when every channel is <= 1 (the
# scientific convention; ADR-018 §5). Returns NA-tolerant in the
# sense that missing values bubble up as a clean check failure.
normalize_rgba <- function(color, default_alpha = 255,
                            arg = "color") {
  checkmate::assert_numeric(
    color, lower = 0, finite = TRUE,
    min.len = 3, max.len = 4,
    any.missing = FALSE, .var.name = arg
  )
  if (max(color) <= 1) {
    color <- color * 255
  } else if (max(color) > 255) {
    stop(sprintf(
      "`%s` channels must be in [0, 255] or [0, 1]; got max %g.",
      arg, max(color)
    ), call. = FALSE)
  }
  if (length(color) == 3L) {
    color <- c(color, default_alpha)
  }
  unname(color)
}

# Internal: overlay named partial RGBA components onto a base
# color vector. Used by composite stroke / fill setters.
overlay_rgba_partial <- function(base, red, green, blue, alpha) {
  if (!is.null(red))   base[1L] <- red
  if (!is.null(green)) base[2L] <- green
  if (!is.null(blue))  base[3L] <- blue
  if (!is.null(alpha)) base[4L] <- alpha
  base
}

# Internal: turn the matrix spec the user passed (length-6 vector
# OR 3x3 homogeneous matrix) into a length-6 (a, b, c, d, e, f).
matrix_to_six <- function(m, arg = "matrix") {
  if (is.matrix(m)) {
    checkmate::assert_matrix(
      m, mode = "numeric", any.missing = FALSE,
      nrows = 3L, ncols = 3L, .var.name = arg
    )
    # Homogeneous form: top-left 2x2 + translation column. Bottom
    # row must be (0, 0, 1) for an affine transform.
    if (!isTRUE(all.equal(m[3L, ], c(0, 0, 1)))) {
      stop(sprintf(
        "`%s` is a 3x3 matrix; bottom row must be (0, 0, 1).",
        arg
      ), call. = FALSE)
    }
    return(c(m[1L, 1L], m[2L, 1L],   # a, b
              m[1L, 2L], m[2L, 2L],  # c, d
              m[1L, 3L], m[2L, 3L])) # e, f
  }
  checkmate::assert_numeric(
    m, len = 6L, any.missing = FALSE, finite = TRUE,
    .var.name = arg
  )
  as.numeric(m)
}

#' Set the affine transformation matrix of a page object
#'
#' Wraps `FPDFPageObj_SetMatrix`. Replaces the page object's current
#' transformation matrix (CTM) with the given 2D affine transform.
#' Accepts either a 3x3 homogeneous matrix (matching the shape
#' [pdf_obj_matrix()] returns) or a length-6 vector
#' `c(a, b, c, d, e, f)` in PDF column-major order.
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()]. Parent doc
#'   must be readwrite.
#' @param matrix Either a 3x3 numeric matrix (with bottom row
#'   `(0, 0, 1)`) or a length-6 numeric vector.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_obj_matrix()] for the read side.
#' @export
pdf_obj_set_matrix <- function(obj, matrix) {
  ctx <- assert_obj_writable(obj)
  six <- matrix_to_six(matrix)
  expect_setter_ok(cpp_obj_set_matrix(obj$ptr, six),
                    "FPDFPageObj_SetMatrix")
  finalize_obj_setter(ctx)
}

#' Set whether a page object renders
#'
#' Wraps `FPDFPageObj_SetIsActive`. When `FALSE`, the object stays
#' in the page's content stream but is skipped during render and
#' export. Useful for soft-hiding annotations or watermarks without
#' deleting them.
#'
#' @inheritParams pdf_obj_set_matrix
#' @param active Logical scalar.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_obj_is_active()] for the read side.
#' @export
pdf_obj_set_active <- function(obj, active) {
  checkmate::assert_flag(active)
  ctx <- assert_obj_writable(obj)
  expect_setter_ok(cpp_obj_set_active(obj$ptr, active),
                    "FPDFPageObj_SetIsActive")
  finalize_obj_setter(ctx)
}

#' Set the blend mode of a page object
#'
#' Wraps `FPDFPageObj_SetBlendMode`. PDF blend modes mirror the
#' Porter-Duff / PDF 1.4 transparency spec. Allowed values:
#' `"Normal"` (default), `"Multiply"`, `"Screen"`, `"Overlay"`,
#' `"Darken"`, `"Lighten"`, `"ColorDodge"`, `"ColorBurn"`,
#' `"HardLight"`, `"SoftLight"`, `"Difference"`, `"Exclusion"`,
#' `"Hue"`, `"Saturation"`, `"Color"`, `"Luminosity"`.
#'
#' @inheritParams pdf_obj_set_matrix
#' @param mode Character scalar; one of the 16 PDF blend mode
#'   names listed above.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_obj_set_blend_mode <- function(obj, mode) {
  checkmate::assert_choice(mode, .pdfium_blend_modes)
  ctx <- assert_obj_writable(obj)
  cpp_obj_set_blend_mode(obj$ptr, mode)
  finalize_obj_setter(ctx)
}

#' Set the stroke style of a path page object
#'
#' Composite setter — accepts named partial updates. Any argument
#' left `NULL` keeps its current value. Wraps
#' `FPDFPageObj_SetStrokeColor` + `FPDFPageObj_SetStrokeWidth`.
#'
#' Color accepts either 0-255 integers or 0-1 doubles (ADR-018 §5);
#' the form is auto-detected from the input range.
#'
#' @param obj A `pdfium_obj` of type `"path"`. Parent doc must be
#'   readwrite.
#' @param color Length-3 (RGB) or length-4 (RGBA) numeric vector,
#'   or `NULL` to keep the current color.
#' @param red,green,blue,alpha Individual channel overrides. Useful
#'   when you want to tweak one component without restating the
#'   rest.
#' @param width Stroke width in points, or `NULL`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_stroke()].
#' @export
pdf_path_set_stroke <- function(obj, color = NULL, width = NULL,
                                  red = NULL, green = NULL,
                                  blue = NULL, alpha = NULL) {
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  any_color <- !is.null(color) || !is.null(red) || !is.null(green) ||
    !is.null(blue) || !is.null(alpha)
  if (any_color) {
    if (!is.null(color)) {
      base <- normalize_rgba(color, arg = "color")
    } else {
      # Read current stroke color; cpp returns named c(r,g,b,a) on
      # success or all-NA if the object has no stroke. Treat NAs as
      # 0 / opaque so the partial overlay never bakes in NA.
      base <- as.numeric(cpp_obj_stroke_color(obj$ptr))
      base[is.na(base)] <- c(0, 0, 0, 255)[is.na(base)]
    }
    base <- overlay_rgba_partial(base, red, green, blue, alpha)
    checkmate::assert_numeric(
      base, lower = 0, upper = 255, len = 4L, any.missing = FALSE
    )
    expect_setter_ok(
      cpp_obj_set_stroke_color(obj$ptr, base[1L], base[2L],
                                 base[3L], base[4L]),
      "FPDFPageObj_SetStrokeColor"
    )
  }
  if (!is.null(width)) {
    checkmate::assert_number(width, lower = 0, finite = TRUE)
    expect_setter_ok(
      cpp_obj_set_stroke_width(obj$ptr, as.numeric(width)),
      "FPDFPageObj_SetStrokeWidth"
    )
  }
  finalize_obj_setter(ctx)
}

#' Set the fill color of a path page object
#'
#' Composite setter — accepts named partial updates. Wraps
#' `FPDFPageObj_SetFillColor`. Color accepts 0-255 ints or 0-1
#' doubles (ADR-018 §5).
#'
#' @inheritParams pdf_path_set_stroke
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_fill()].
#' @export
pdf_path_set_fill <- function(obj, color = NULL,
                                red = NULL, green = NULL,
                                blue = NULL, alpha = NULL) {
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  if (!is.null(color)) {
    base <- normalize_rgba(color, arg = "color")
  } else {
    base <- as.numeric(cpp_obj_fill_color(obj$ptr))
    base[is.na(base)] <- c(0, 0, 0, 255)[is.na(base)]
  }
  base <- overlay_rgba_partial(base, red, green, blue, alpha)
  checkmate::assert_numeric(
    base, lower = 0, upper = 255, len = 4L, any.missing = FALSE
  )
  expect_setter_ok(
    cpp_obj_set_fill_color(obj$ptr, base[1L], base[2L],
                             base[3L], base[4L]),
    "FPDFPageObj_SetFillColor"
  )
  finalize_obj_setter(ctx)
}

#' Set the line cap style of a path stroke
#'
#' Wraps `FPDFPageObj_SetLineCap`. Allowed values: `"butt"`,
#' `"round"`, `"projecting_square"`.
#'
#' @inheritParams pdf_path_set_stroke
#' @param cap Character scalar; one of `"butt"`, `"round"`,
#'   `"projecting_square"`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_line_cap()].
#' @export
pdf_path_set_line_cap <- function(obj, cap) {
  checkmate::assert_choice(cap, .pdfium_line_caps)
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  code <- match(cap, .pdfium_line_caps) - 1L
  expect_setter_ok(cpp_obj_set_line_cap(obj$ptr, code),
                    "FPDFPageObj_SetLineCap")
  finalize_obj_setter(ctx)
}

#' Set the line join style of a path stroke
#'
#' Wraps `FPDFPageObj_SetLineJoin`. Allowed values: `"miter"`,
#' `"round"`, `"bevel"`.
#'
#' @inheritParams pdf_path_set_stroke
#' @param join Character scalar; one of `"miter"`, `"round"`,
#'   `"bevel"`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_line_join()].
#' @export
pdf_path_set_line_join <- function(obj, join) {
  checkmate::assert_choice(join, .pdfium_line_joins)
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  code <- match(join, .pdfium_line_joins) - 1L
  expect_setter_ok(cpp_obj_set_line_join(obj$ptr, code),
                    "FPDFPageObj_SetLineJoin")
  finalize_obj_setter(ctx)
}

#' Set the dash array + phase of a path stroke
#'
#' Wraps `FPDFPageObj_SetDashArray`. Pass an empty vector to clear
#' the dash (continuous stroke).
#'
#' @inheritParams pdf_path_set_stroke
#' @param array Numeric vector of dash lengths (alternating on / off
#'   in PDF points), or `numeric(0)` for a continuous stroke.
#' @param phase Numeric scalar; offset (in PDF points) into the
#'   dash pattern at which to start drawing. Default `0`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_dash()].
#' @export
pdf_path_set_dash <- function(obj, array, phase = 0) {
  checkmate::assert_numeric(array, lower = 0, finite = TRUE,
                             any.missing = FALSE)
  checkmate::assert_number(phase, finite = TRUE)
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  expect_setter_ok(
    cpp_obj_set_dash(obj$ptr, as.numeric(array), as.numeric(phase)),
    "FPDFPageObj_SetDashArray"
  )
  finalize_obj_setter(ctx)
}

#' Set the draw mode of a path page object
#'
#' Wraps `FPDFPath_SetDrawMode`. Controls whether the path is
#' filled, stroked, or both.
#'
#' @inheritParams pdf_path_set_stroke
#' @param fill_mode Character scalar; one of `"none"`, `"even_odd"`
#'   (the PDF even-odd / alternate rule), or `"winding"` (the
#'   non-zero winding rule). Matches [pdf_path_draw_mode()]'s
#'   `fill_mode` column.
#' @param stroke Logical scalar.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_draw_mode()].
#' @export
pdf_path_set_draw_mode <- function(obj, fill_mode, stroke) {
  checkmate::assert_choice(fill_mode, .pdfium_fill_modes)
  checkmate::assert_flag(stroke)
  ctx <- assert_obj_writable(obj, allowed_types = "path")
  code <- match(fill_mode, .pdfium_fill_modes) - 1L
  expect_setter_ok(cpp_path_set_draw_mode(obj$ptr, code, stroke),
                    "FPDFPath_SetDrawMode")
  finalize_obj_setter(ctx)
}

#' Replace the text content of a text page object
#'
#' Wraps `FPDFText_SetText`. Replaces whatever text the object
#' carries with `text` (UTF-8). PDFium re-encodes for the
#' embedded font; characters the font can't render fall back to
#' the spec's substitution rules.
#'
#' @param obj A `pdfium_obj` of type `"text"`. Parent doc must be
#'   readwrite.
#' @param text Character scalar (UTF-8).
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_text_content()].
#' @export
pdf_text_set_content <- function(obj, text) {
  checkmate::assert_string(text, na.ok = FALSE)
  ctx <- assert_obj_writable(obj, allowed_types = "text")
  expect_setter_ok(cpp_text_set_content(obj$ptr, enc2utf8(text)),
                    "FPDFText_SetText")
  finalize_obj_setter(ctx)
}

#' Set the render mode of a text page object
#'
#' Wraps `FPDFTextObj_SetTextRenderMode`. Allowed values mirror
#' [pdf_text_render_mode()]'s names: `"fill"`, `"stroke"`,
#' `"fill_stroke"`, `"invisible"`, `"fill_clip"`, `"stroke_clip"`,
#' `"fill_stroke_clip"`, `"clip"`.
#'
#' @inheritParams pdf_text_set_content
#' @param mode Character scalar; one of the eight render-mode
#'   names listed above.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_text_render_mode()].
#' @export
pdf_text_set_render_mode <- function(obj, mode) {
  checkmate::assert_choice(mode, .pdfium_text_render_modes)
  ctx <- assert_obj_writable(obj, allowed_types = "text")
  code <- match(mode, .pdfium_text_render_modes) - 1L
  expect_setter_ok(cpp_text_set_render_mode(obj$ptr, code),
                    "FPDFTextObj_SetTextRenderMode")
  finalize_obj_setter(ctx)
}

#' Add a content mark to a page object
#'
#' Wraps `FPDFPageObj_AddMark`. Content marks tag the object for
#' downstream consumers (the structure tree, custom workflows).
#' Optional `params` are written via `FPDFPageObjMark_SetIntParam`
#' or `_SetStringParam` depending on each value's R type.
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()]. Parent doc
#'   must be readwrite.
#' @param name Character scalar — the mark's name (e.g. `"Span"`,
#'   `"Artifact"`, `"MCID"`).
#' @param params Optional named list of integer- or character-typed
#'   parameter values to attach to the mark. Numeric values are
#'   coerced to integer; character values are written as strings.
#'   Other types raise an error.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_obj_marks()], [pdf_obj_remove_mark()].
#' @export
pdf_obj_add_mark <- function(obj, name, params = list()) {
  checkmate::assert_string(name, min.chars = 1L)
  checkmate::assert_list(params, names = "named")
  ctx <- assert_obj_writable(obj)
  idx0 <- cpp_obj_add_mark(obj$ptr, name)
  if (idx0 < 0L) {
    stop("FPDFPageObj_AddMark failed.", call. = FALSE)  # nocov
  }
  if (length(params) > 0L) {
    doc_ptr <- ctx$doc$ptr
    for (key in names(params)) {
      value <- params[[key]]
      if (is.character(value)) {
        checkmate::assert_string(value, .var.name = paste0("params$", key))
        ok <- cpp_obj_mark_set_string_param(
          doc_ptr, obj$ptr, idx0, key, value
        )
      } else if (is.numeric(value)) {
        checkmate::assert_number(value, finite = TRUE,
                                  .var.name = paste0("params$", key))
        ok <- cpp_obj_mark_set_int_param(
          doc_ptr, obj$ptr, idx0, key, as.integer(value)
        )
      } else {
        stop(sprintf(
          "params$%s must be a character or numeric scalar.", key
        ), call. = FALSE)
      }
      expect_setter_ok(
        ok, sprintf("Content-mark parameter '%s'", key)
      )
    }
  }
  finalize_obj_setter(ctx)
}

#' Remove a content mark from a page object
#'
#' Wraps `FPDFPageObj_RemoveMark`. `mark_index` is 1-based and
#' matches the row order [pdf_obj_marks()] returns; removing a mark
#' shifts every subsequent mark's index down by one.
#'
#' @inheritParams pdf_obj_add_mark
#' @param mark_index One-based index of the mark to remove.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_obj_marks()], [pdf_obj_add_mark()].
#' @export
pdf_obj_remove_mark <- function(obj, mark_index) {
  checkmate::assert_count(mark_index, positive = TRUE)
  ctx <- assert_obj_writable(obj)
  expect_setter_ok(
    cpp_obj_remove_mark(obj$ptr, as.integer(mark_index) - 1L),
    "FPDFPageObj_RemoveMark"
  )
  finalize_obj_setter(ctx)
}
