# Annotation authoring (Phase 6 of the v0.1.0 writer surface).
#
# Two exports do the create / delete bookends — `pdf_annot_new`
# returns a `pdfium_annot` for a freshly-created annotation, and
# `pdf_annot_delete` removes one and invalidates its R-side
# handle. The remaining nine are per-attribute setters that mirror
# every `pdf_annot_*` reader shipped in 0.1.0. Each takes a pdfium_annot
# whose parent doc is readwrite, validates the new value, calls
# the matching FPDFAnnot_Set* symbol, marks the parent page dirty
# so pdf_save() / pdf_render_*() see the change, and invisibly
# returns the parent doc for chaining.
#
# A few PDFium-side specifics:
# * Color setters accept either 0-255 ints or 0-1 doubles (ADR-018
#   §5); the inherited `normalize_rgba()` from R/obj_setters.R does
#   the auto-detection.
# * String setters (contents / title / subject / arbitrary key)
#   route through FPDFAnnot_SetStringValue with a NUL-terminated
#   UTF-16LE encoded value; the R wrapper passes UTF-8.
# * Flag setter accepts either a raw integer bitmask or a named
#   logical vector matching the existing `.pdfium_annot_flag_bits`
#   table.

# Internal validator. Returns the parent doc + page index for use
# by finalize_annot_setter().
assert_annot_writable <- function(annot, arg = "annot") {
  check_annot(annot, arg = arg)
  doc <- annot$page$doc
  assert_readwrite(doc)
  list(doc = doc, page_index = annot$page$index)
}

# Mark the parent page dirty + return the doc invisibly. Mirror of
# finalize_obj_setter() but for annotation setters.
finalize_annot_setter <- function(ctx) {
  mark_page_dirty(ctx$doc, ctx$page_index)
  invisible(ctx$doc)
}

#' Create a new annotation on a page
#'
#' Wraps `FPDFPage_CreateAnnot` + (optionally) `FPDFAnnot_SetRect`.
#' PDFium supports creating annotations of subtype `"circle"`,
#' `"fileattachment"`, `"freetext"`, `"highlight"`, `"ink"`,
#' `"link"`, `"popup"`, `"square"`, `"squiggly"`, `"stamp"`,
#' `"strikeout"`, `"text"`, and `"underline"`. Other subtypes
#' (`"widget"`, `"polygon"`, `"line"`, etc.) error from PDFium.
#'
#' The new annotation is appended to the page's `/Annots` array.
#' Use [pdf_annotations()] to re-read the page if you need an
#' updated handle list — the new annotation lands at the end.
#'
#' @param page A `pdfium_page` from [pdf_page_load()]. Parent doc
#'   must be readwrite.
#' @param subtype Character scalar — one of the supported annotation
#'   subtypes listed above.
#' @param bounds Optional length-4 numeric vector
#'   `c(left, bottom, right, top)` in PDF user-space points. Default
#'   `NULL` (annotation has no rect set — most subtypes still need
#'   one and you'll likely follow up with
#'   [pdf_annot_set_bounds()]).
#' @return The new `pdfium_annot` handle.
#' @seealso [pdf_annot_delete()], [pdf_annot_set_bounds()],
#'   [pdf_annot_set_color()], [pdf_annot_set_contents()].
#' @export
pdf_annot_new <- function(page, subtype, bounds = NULL) {
  checkmate::assert_string(subtype)
  if (!is.null(bounds)) {
    checkmate::assert_numeric(
      bounds, len = 4L, any.missing = FALSE, finite = TRUE
    )
  }
  code <- pdfium_annot_subtype_code(subtype)
  if (code == 0L && subtype != "unknown") {
    stop(sprintf(
      "Unknown annotation subtype: '%s'. See ?pdf_annot_new for the ",
      "list of supported names."
    ), subtype, call. = FALSE)
  }
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  ptr <- cpp_annot_new(ph$page$ptr, code)
  idx <- cpp_annot_count(ph$page$ptr)
  if (!is.null(bounds)) {
    expect_setter_ok(
      cpp_annot_set_rect(ptr, bounds[[1L]], bounds[[2L]],
                          bounds[[3L]], bounds[[4L]]),
      "FPDFAnnot_SetRect"
    )
  }
  mark_page_dirty(ph$doc, ph$page$index)
  new_pdfium_annot(ptr, ph$page, idx)
}

#' Remove an annotation and invalidate the handle
#'
#' Wraps `FPDFPage_RemoveAnnot`. After the call, the annotation is
#' gone from the page's `/Annots` array, the underlying
#' `FPDF_ANNOTATION` is destroyed, and the R handle's externalptr
#' is cleared so further `pdf_annot_*` calls on it error cleanly
#' via [is_open()].
#'
#' Page-scoped indices on other annotation handles shift after a
#' deletion; re-fetch via [pdf_annotations()] if you need fresh
#' indices.
#'
#' @param annot A `pdfium_annot` handle. Parent doc must be
#'   readwrite.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_new()], [pdf_annotations()].
#' @export
pdf_annot_delete <- function(annot) {
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_delete(annot$page$ptr, annot$ptr,
                      as.integer(annot$index) - 1L),
    "FPDFPage_RemoveAnnot"
  )
  finalize_annot_setter(ctx)
}

#' Set the bounding rectangle of an annotation
#'
#' Wraps `FPDFAnnot_SetRect`. Replaces the `/Rect` entry with the
#' given `(left, bottom, right, top)` in PDF user-space points.
#'
#' @param annot A `pdfium_annot` handle. Parent doc must be
#'   readwrite.
#' @param bounds Length-4 numeric vector
#'   `c(left, bottom, right, top)`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_bounds()].
#' @export
pdf_annot_set_bounds <- function(annot, bounds) {
  checkmate::assert_numeric(
    bounds, len = 4L, any.missing = FALSE, finite = TRUE
  )
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_rect(annot$ptr,
                        as.numeric(bounds[[1L]]),
                        as.numeric(bounds[[2L]]),
                        as.numeric(bounds[[3L]]),
                        as.numeric(bounds[[4L]])),
    "FPDFAnnot_SetRect"
  )
  finalize_annot_setter(ctx)
}

# Internal: shared body for the two color setters (Color and
# InteriorColor) so we don't duplicate the normalize / overlay /
# call flow.
#
# Important units note: the corresponding readers (pdf_annot_color
# and pdf_annot_interior_color) return 0..1 doubles, so when this
# function reads the *current* color via `reader_fn` it has to
# scale back to 0..255 before the overlay step. Otherwise mixing a
# user-provided 0..255 channel override with a 0..1 base
# accidentally clamps the unchanged channels to near-zero.
annot_set_color_impl <- function(annot, color_type_code,
                                   color, red, green, blue, alpha,
                                   reader_fn) {
  ctx <- assert_annot_writable(annot)
  if (!is.null(color)) {
    base <- normalize_rgba(color, arg = "color")
  } else {
    base_01 <- as.numeric(reader_fn(annot))
    base_01[is.na(base_01)] <- c(0, 0, 0, 1)[is.na(base_01)]
    base <- base_01 * 255
  }
  base <- overlay_rgba_partial(base, red, green, blue, alpha)
  checkmate::assert_numeric(
    base, lower = 0, upper = 255, len = 4L, any.missing = FALSE
  )
  expect_setter_ok(
    cpp_annot_set_color(annot$ptr, color_type_code,
                         base[1L], base[2L], base[3L], base[4L]),
    "FPDFAnnot_SetColor"
  )
  finalize_annot_setter(ctx)
}

#' Set the stroke / line color of an annotation
#'
#' Wraps `FPDFAnnot_SetColor` with `type = FPDFANNOT_COLORTYPE_Color`.
#' Composite setter — pass `color = c(r, g, b)` (or `c(r, g, b, a)`)
#' for a full replacement, or individual `red` / `green` / `blue` /
#' `alpha` arguments for a partial overlay on the current color.
#' 0-255 ints and 0-1 doubles are auto-detected per ADR-018 §5.
#'
#' @param annot A `pdfium_annot` handle. Parent doc must be
#'   readwrite.
#' @param color Length-3 (RGB) or length-4 (RGBA) numeric vector,
#'   or `NULL` to keep the current color and rely on the
#'   per-channel overrides.
#' @param red,green,blue,alpha Individual channel overrides.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_color()],
#'   [pdf_annot_set_interior_color()].
#' @export
pdf_annot_set_color <- function(annot, color = NULL,
                                  red = NULL, green = NULL,
                                  blue = NULL, alpha = NULL) {
  annot_set_color_impl(annot, color_type_code = 0L,
                        color = color, red = red, green = green,
                        blue = blue, alpha = alpha,
                        reader_fn = pdf_annot_color)
}

#' Set the interior / fill color of an annotation
#'
#' Wraps `FPDFAnnot_SetColor` with
#' `type = FPDFANNOT_COLORTYPE_InteriorColor`. Same composite
#' shape as [pdf_annot_set_color()]; auto-detects 0-255 vs 0-1
#' color form.
#'
#' @inheritParams pdf_annot_set_color
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_interior_color()],
#'   [pdf_annot_set_color()].
#' @export
pdf_annot_set_interior_color <- function(annot, color = NULL,
                                           red = NULL,
                                           green = NULL,
                                           blue = NULL,
                                           alpha = NULL) {
  annot_set_color_impl(annot, color_type_code = 1L,
                        color = color, red = red, green = green,
                        blue = blue, alpha = alpha,
                        reader_fn = pdf_annot_interior_color)
}

#' Set the flags bitmask of an annotation
#'
#' Wraps `FPDFAnnot_SetFlags`. Accepts either an integer bitmask or
#' a named logical vector matching the names that
#' [pdf_annot_flags_decoded()] returns (`is_invisible`,
#' `is_hidden`, `is_print`, `is_no_view`, `is_read_only`,
#' `is_locked`, ...). When a named logical is passed, any TRUE
#' position sets the corresponding bit; FALSE clears it.
#'
#' @param annot A `pdfium_annot` handle. Parent doc must be
#'   readwrite.
#' @param flags Either an integer scalar (raw PDF /F bitmask) or a
#'   named logical vector with the documented flag-bit names.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_flags()], [pdf_annot_flags_decoded()].
#' @export
pdf_annot_set_flags <- function(annot, flags) {
  ctx <- assert_annot_writable(annot)
  if (is.logical(flags)) {
    checkmate::assert_named(flags, type = "unique")
    encoded <- pdfium_annot_flag_encode(flags)
  } else {
    checkmate::assert_int(flags, lower = 0)
    encoded <- as.integer(flags)
  }
  expect_setter_ok(
    cpp_annot_set_flags(annot$ptr, encoded),
    "FPDFAnnot_SetFlags"
  )
  finalize_annot_setter(ctx)
}

# Internal: encode a named logical vector (matching
# pdfium_annot_flag_decode's output shape) into a raw integer flag
# bitmask. Unknown names error.
pdfium_annot_flag_encode <- function(named_lgl) {
  recognised <- names(.pdfium_annot_flag_bits)
  bad <- setdiff(names(named_lgl), recognised)
  if (length(bad) > 0L) {
    stop(sprintf(
      "Unknown annotation flag bits: %s",
      paste(shQuote(bad), collapse = ", ")
    ), call. = FALSE)
  }
  bitmask <- 0L
  for (nm in names(named_lgl)) {
    if (isTRUE(named_lgl[[nm]])) {
      bitmask <- bitwOr(bitmask,
                          bitwShiftL(1L, .pdfium_annot_flag_bits[[nm]] - 1L))
    }
  }
  bitmask
}

#' Set the `/Contents` text of an annotation
#'
#' Wraps `FPDFAnnot_SetStringValue(annot, "Contents", text)`. The
#' Contents entry is the visible body / popup-message text on most
#' annotation subtypes.
#'
#' @param annot A `pdfium_annot` handle. Parent doc must be
#'   readwrite.
#' @param text Character scalar (UTF-8).
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_contents()], [pdf_annot_set_title()],
#'   [pdf_annot_set_subject()], [pdf_annot_set_dict_value()].
#' @export
pdf_annot_set_contents <- function(annot, text) {
  checkmate::assert_string(text, na.ok = FALSE)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_string_value(annot$ptr, "Contents",
                                 enc2utf8(text)),
    "FPDFAnnot_SetStringValue(Contents)"
  )
  finalize_annot_setter(ctx)
}

#' Set the `/T` (title / author) of an annotation
#'
#' Wraps `FPDFAnnot_SetStringValue(annot, "T", text)`. By
#' convention the `/T` entry holds the annotation author's name
#' (Acrobat shows it as "Author").
#'
#' @inheritParams pdf_annot_set_contents
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_title()].
#' @export
pdf_annot_set_title <- function(annot, text) {
  checkmate::assert_string(text, na.ok = FALSE)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_string_value(annot$ptr, "T", enc2utf8(text)),
    "FPDFAnnot_SetStringValue(T)"
  )
  finalize_annot_setter(ctx)
}

#' Set the `/Subj` (subject) of an annotation
#'
#' Wraps `FPDFAnnot_SetStringValue(annot, "Subj", text)`. The
#' subject is a brief descriptor (e.g. "Highlight") that some
#' PDF readers surface separately from `/Contents`.
#'
#' @inheritParams pdf_annot_set_contents
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_subject()].
#' @export
pdf_annot_set_subject <- function(annot, text) {
  checkmate::assert_string(text, na.ok = FALSE)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_string_value(annot$ptr, "Subj", enc2utf8(text)),
    "FPDFAnnot_SetStringValue(Subj)"
  )
  finalize_annot_setter(ctx)
}

#' Set an arbitrary string-valued entry on an annotation dict
#'
#' Wraps `FPDFAnnot_SetStringValue` for callers that want to write
#' a specific `/key value` pair beyond the common
#' `/Contents` / `/T` / `/Subj` shortcuts. Symmetric with
#' [pdf_annot_dict_value()] for reading.
#'
#' @inheritParams pdf_annot_set_contents
#' @param key Character scalar — the PDF dictionary key
#'   (e.g. `"CreationDate"`, `"NM"`, `"M"`).
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_dict_value()],
#'   [pdf_annot_set_contents()].
#' @export
pdf_annot_set_dict_value <- function(annot, key, text) {
  key <- assert_pdf_key(key, arg = "key")
  checkmate::assert_string(text, na.ok = FALSE)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_string_value(annot$ptr, key, enc2utf8(text)),
    sprintf("FPDFAnnot_SetStringValue(%s)", key)
  )
  finalize_annot_setter(ctx)
}

#' Append a quad to an annotation's `/QuadPoints` array
#'
#' Wraps `FPDFAnnot_AppendAttachmentPoints`. Each quad is four
#' `(x, y)` points giving the corners of a tile in
#' counterclockwise order (matching the shape
#' [pdf_annot_quad_points()] reads back). For highlight /
#' underline / squiggly / strikeout annotations a quad covers each
#' affected text run; a typical paragraph-spanning highlight has
#' one quad per visual line.
#'
#' @inheritParams pdf_annot_set_contents
#' @param quad Length-8 numeric vector
#'   `c(x1, y1, x2, y2, x3, y3, x4, y4)`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_quad_points()].
#' @export
pdf_annot_append_quad <- function(annot, quad) {
  checkmate::assert_numeric(
    quad, len = 8L, any.missing = FALSE, finite = TRUE
  )
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_append_quad(annot$ptr,
                            quad[[1L]], quad[[2L]],
                            quad[[3L]], quad[[4L]],
                            quad[[5L]], quad[[6L]],
                            quad[[7L]], quad[[8L]]),
    "FPDFAnnot_AppendAttachmentPoints"
  )
  finalize_annot_setter(ctx)
}
