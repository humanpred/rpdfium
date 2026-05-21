# pdfium R package — v0.1.0 "complete the relevant PDFium surface" pass.
#
# This file collects user-facing wrappers for the last batch of single-call
# PDFium symbols that had been deferred to v0.2.0 but are now part of the
# v0.1.0 release. Functions are organised by topical group (text-low-level,
# page-coordinate, page-metadata, font, mark, page-object). Internal Rcpp
# shims live in src/api_completion.cpp.
#
# Phase A — simple readers + getters. Phases B (annotation authoring),
# C (clip-path), D (form-XObjects), E (image-bitmap), F (custom-load),
# and G (system fonts) live in sibling files.

# ---- Document-level ------------------------------------------------------

#' Form-type flavour of the document
#'
#' Wraps `FPDF_GetFormType` to report whether the document carries an
#' AcroForm (`"acro_form"`), a full XFA form (`"xfa_full"`), an XFA
#' foreground overlay on top of an AcroForm (`"xfa_foreground"`), or no
#' form at all (`"none"`).
#'
#' AcroForm is what `pdf_form_fields()` enumerates; XFA forms are an
#' Adobe-specific dialect that PDFium does not interpret (you can detect
#' them with this function and warn the user to use Adobe Reader).
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()].
#' @return Character scalar — one of `"none"`, `"acro_form"`,
#'   `"xfa_full"`, `"xfa_foreground"`.
#' @seealso [pdf_form_fields()].
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_doc_open(fixture)
#'   pdf_doc_form_type(doc)
#'   pdf_doc_close(doc)
#' }
#' @export
pdf_doc_form_type <- function(doc) {
  checkmate::assert_class(doc, "pdfium_doc")
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  code <- cpp_doc_form_type(doc$ptr)
  out <- .pdfium_form_type_names[as.character(code)]
  if (is.null(out) || is.na(out)) "none" else unname(out)
}

# Static table — PDFium FORMTYPE_* codes from fpdf_formfill.h.
.pdfium_form_type_names <- c(
  "0" = "none",
  "1" = "acro_form",
  "2" = "xfa_full",
  "3" = "xfa_foreground"
)

# Tiny coalesce helper. Reused across api_completion functions.
`%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a

# ---- Bookmark ------------------------------------------------------------

#' Number of children for a bookmark
#'
#' Wraps `FPDFBookmark_GetCount` — returns the count of direct child
#' bookmarks under a given outline entry. Useful when you have a single
#' `pdfium_bookmark` handle (e.g. from
#' [pdf_doc_bookmark_find()]) and want to know whether it expands.
#'
#' The full pre-order outline (with `parent_index` columns) is available
#' via [pdf_doc_bookmarks()]; this function is the per-handle accessor.
#'
#' @param bookmark A `pdfium_bookmark` from [pdf_doc_bookmarks()] or
#'   [pdf_doc_bookmark_find()].
#' @return Integer scalar — the number of direct children. `0` if the
#'   bookmark has no children.
#' @export
pdf_bookmark_child_count <- function(bookmark) {
  checkmate::assert_class(bookmark, "pdfium_bookmark")
  if (!is_open(bookmark)) {
    stop("Bookmark handle has been closed.", call. = FALSE)
  }
  cpp_bookmark_child_count(bookmark$ptr)
}

# ---- Page metadata + transparency ----------------------------------------

#' Does the page contain transparency?
#'
#' Wraps `FPDFPage_HasTransparency`. Returns `TRUE` if any page object
#' on `page` uses alpha blending or a transparency group. PDFium needs
#' this hint when laying out the rendering pipeline; downstream
#' analyses (e.g. flattening to opaque colors) also care.
#'
#' @param page A `pdfium_page` from [pdf_page_load()].
#' @return Logical scalar.
#' @export
pdf_page_has_transparency <- function(page) {
  checkmate::assert_class(page, "pdfium_page")
  if (!is_open(page)) {
    stop("Page has been closed.", call. = FALSE)
  }
  cpp_page_has_transparency(page$ptr)
}

#' Page bounding box (cropbox ∩ mediabox)
#'
#' Wraps `FPDF_GetPageBoundingBox` — returns the rectangle that
#' encloses the visible portion of `page` after intersecting the
#' cropbox with the mediabox. Often the same as the cropbox; differs
#' when a cropbox sticks out beyond the mediabox.
#'
#' For named boxes (media / crop / bleed / trim / art), use
#' [pdf_page_box()].
#'
#' @param page A `pdfium_page` from [pdf_page_load()].
#' @return Named numeric vector of length 4 — `c(left, bottom, right,
#'   top)` in PDF user-space points. All-`NA` on failure.
#' @seealso [pdf_page_box()] for individual named boxes.
#' @export
pdf_page_bounding_box <- function(page) {
  checkmate::assert_class(page, "pdfium_page")
  if (!is_open(page)) {
    stop("Page has been closed.", call. = FALSE)
  }
  cpp_page_bounding_box(page$ptr)
}

#' Transform every annotation on a page in one shot
#'
#' Wraps `FPDFPage_TransformAnnots`. Applies the 6-tuple matrix
#' `(a, b, c, d, e, f)` to all annotations on `page` simultaneously —
#' the same matrix shape used by [pdf_obj_set_matrix()] for page
#' objects.
#'
#' Polymorphic in `page`: accepts either a `pdfium_page` (with parent
#' doc readwrite) or a `pdfium_doc` plus `page_num`.
#'
#' @param page A `pdfium_page` or `pdfium_doc`.
#' @param matrix Numeric length-6 vector `c(a, b, c, d, e, f)`.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_page_transform_annots <- function(page, matrix, page_num = 1L) {
  checkmate::assert_numeric(matrix, len = 6L, any.missing = FALSE,
                             finite = TRUE)
  ph <- as_page_and_doc(page, page_num)
  assert_readwrite(ph$doc)
  cpp_page_transform_annots(ph$page$ptr,
                              matrix[[1L]], matrix[[2L]], matrix[[3L]],
                              matrix[[4L]], matrix[[5L]], matrix[[6L]])
  mark_page_dirty(ph$doc, ph$page$index)
  invisible(ph$doc)
}

#' Find an annotation's page-relative index by handle
#'
#' Wraps `FPDFPage_GetAnnotIndex`. Useful after [pdf_annot_new()] when
#' you want to know the position of the freshly-created annotation
#' inside the page's annot list (e.g. to coordinate with index-driven
#' code paths).
#'
#' @param annot A `pdfium_annot` from [pdf_annot_new()] or
#'   [pdf_annotations()].
#' @return Integer scalar — one-based annotation index on the parent
#'   page, or `NA_integer_` if the annotation is not found.
#' @seealso [pdf_annotations()].
#' @export
pdf_annot_index <- function(annot) {
  checkmate::assert_class(annot, "pdfium_annot")
  if (!is_open(annot)) {
    stop("Annotation handle has been closed.", call. = FALSE)
  }
  idx <- cpp_page_annot_index(annot$page$ptr, annot$ptr)
  if (idx < 0) NA_integer_ else (idx + 1L)
}

# ---- Device ↔ page coordinate conversion ---------------------------------

#' Convert device (screen) coordinates to PDF page coordinates
#'
#' Wraps `FPDF_DeviceToPage`. Given a rendering window of size
#' `(size_x, size_y)` pixels at top-left `(start_x, start_y)` with
#' rotation `rotate`, maps the device pixel `(device_x, device_y)` to
#' a point in PDF user-space (points).
#'
#' Useful when a downstream consumer reports a click position in pixels
#' (e.g. from a Shiny `clickOpts` event) and you want to translate it
#' back to PDF coordinates for hit-testing against page objects.
#'
#' @param page A `pdfium_page` from [pdf_page_load()].
#' @param start_x,start_y Integer — device-pixel position of the
#'   display area's top-left.
#' @param size_x,size_y Integer — pixel size of the rendering window.
#' @param rotate Integer — `0`, `1`, `2`, or `3` (clockwise quarter
#'   turns). Same convention as PDFium's other rendering functions.
#' @param device_x,device_y Integer — the pixel to convert.
#' @return Named numeric vector `c(x, y)` in PDF points. `c(NA, NA)`
#'   on failure.
#' @seealso [pdf_page_to_device()] for the inverse.
#' @export
pdf_device_to_page <- function(page, start_x, start_y, size_x, size_y,
                                rotate, device_x, device_y) {
  checkmate::assert_class(page, "pdfium_page")
  if (!is_open(page)) {
    stop("Page has been closed.", call. = FALSE)
  }
  checkmate::assert_int(start_x)
  checkmate::assert_int(start_y)
  checkmate::assert_int(size_x, lower = 1L)
  checkmate::assert_int(size_y, lower = 1L)
  checkmate::assert_choice(rotate, c(0L, 1L, 2L, 3L))
  checkmate::assert_int(device_x)
  checkmate::assert_int(device_y)
  cpp_device_to_page(page$ptr,
                      as.integer(start_x), as.integer(start_y),
                      as.integer(size_x), as.integer(size_y),
                      as.integer(rotate),
                      as.integer(device_x), as.integer(device_y))
}

#' Convert PDF page coordinates to device (screen) coordinates
#'
#' Inverse of [pdf_device_to_page()]. Wraps `FPDF_PageToDevice`.
#'
#' @inheritParams pdf_device_to_page
#' @param page_x,page_y Numeric — the point in PDF user-space (points)
#'   to convert.
#' @return Named integer vector `c(x, y)` in device pixels.
#'   `c(NA, NA)` on failure.
#' @seealso [pdf_device_to_page()].
#' @export
pdf_page_to_device <- function(page, start_x, start_y, size_x, size_y,
                                rotate, page_x, page_y) {
  checkmate::assert_class(page, "pdfium_page")
  if (!is_open(page)) {
    stop("Page has been closed.", call. = FALSE)
  }
  checkmate::assert_int(start_x)
  checkmate::assert_int(start_y)
  checkmate::assert_int(size_x, lower = 1L)
  checkmate::assert_int(size_y, lower = 1L)
  checkmate::assert_choice(rotate, c(0L, 1L, 2L, 3L))
  checkmate::assert_number(page_x, finite = TRUE)
  checkmate::assert_number(page_y, finite = TRUE)
  cpp_page_to_device(page$ptr,
                      as.integer(start_x), as.integer(start_y),
                      as.integer(size_x), as.integer(size_y),
                      as.integer(rotate),
                      as.numeric(page_x), as.numeric(page_y))
}

# ---- Text low-level geometry --------------------------------------------

#' Rectangles occupied by a character range
#'
#' Wraps `FPDFText_CountRects` + `FPDFText_GetRect`. Returns the
#' rectangular regions occupied by the characters in
#' `[start_char, start_char + char_count)` on `page`. Multi-line text
#' produces one rectangle per line; rotated or skewed text produces
#' tighter axis-aligned rectangles per glyph cluster.
#'
#' @param page A `pdfium_page` from [pdf_page_load()].
#' @param start_char One-based character index (matches
#'   `pdf_text_chars()$char_index`).
#' @param char_count Number of characters to cover. Use `-1L` to
#'   include everything from `start_char` to the end of the page.
#' @return A tibble with columns `left`, `top`, `right`, `bottom` in
#'   PDF user-space points. May have 0 rows if PDFium reports no
#'   visible rectangles.
#' @seealso [pdf_text_chars()] for per-character geometry.
#' @export
pdf_text_rects <- function(page, start_char = 1L, char_count = -1L) {
  checkmate::assert_class(page, "pdfium_page")
  if (!is_open(page)) {
    stop("Page has been closed.", call. = FALSE)
  }
  checkmate::assert_int(start_char, lower = 1L)
  checkmate::assert_int(char_count)
  raw <- cpp_text_rects(page$ptr,
                         as.integer(start_char) - 1L,
                         as.integer(char_count))
  tibble::tibble(
    left   = raw$left,
    top    = raw$top,
    right  = raw$right,
    bottom = raw$bottom
  )
}

#' Extract text inside a bounding rectangle
#'
#' Wraps `FPDFText_GetBoundedText`. Returns the Unicode characters on
#' `page` whose glyph centers fall inside the rectangle defined by
#' `(left, bottom, right, top)` in PDF user-space points.
#'
#' Pairs naturally with [pdf_text_rects()] (which produces the
#' rectangles in the first place) and with downstream geometry-driven
#' extraction workflows.
#'
#' @param page A `pdfium_page` from [pdf_page_load()].
#' @param bounds Numeric length-4 vector `c(left, bottom, right, top)`.
#' @return Character scalar. Empty string `""` when no characters fall
#'   inside the rectangle.
#' @seealso [pdf_text_rects()], [pdf_doc_text()].
#' @export
pdf_text_bounded <- function(page, bounds) {
  checkmate::assert_class(page, "pdfium_page")
  if (!is_open(page)) {
    stop("Page has been closed.", call. = FALSE)
  }
  checkmate::assert_numeric(bounds, len = 4L, any.missing = FALSE,
                             finite = TRUE)
  cpp_text_bounded(page$ptr,
                    as.numeric(bounds[[1L]]),
                    as.numeric(bounds[[4L]]),
                    as.numeric(bounds[[3L]]),
                    as.numeric(bounds[[2L]]))
}

#' Per-character geometry: transformation matrix, rotation angle,
#' font weight
#'
#' Wraps `FPDFText_GetMatrix`, `FPDFText_GetCharAngle`, and
#' `FPDFText_GetFontWeight`. Returns a tibble with one row per
#' character on `page` (matching the row count of
#' [pdf_text_chars()]).
#'
#' The `matrix` column is a 6-column numeric matrix where row `i`
#' holds the `(a, b, c, d, e, f)` 2D affine matrix for character `i`
#' (1-indexed). `angle_deg` is the rotation in degrees; `font_weight`
#' is PDFium's CSS-style weight integer (e.g. 400 = regular, 700 =
#' bold), `NA_integer_` if PDFium can't determine it.
#'
#' @param page A `pdfium_page` from [pdf_page_load()].
#' @return A tibble with columns `char_index`, `matrix`, `angle_deg`,
#'   `font_weight`. The matrix column is *stored as a list-column of
#'   length-6 numeric vectors* so the tibble round-trips through
#'   `dplyr` cleanly.
#' @seealso [pdf_text_chars()] for the broader per-character tibble.
#' @export
pdf_text_char_geometry <- function(page) {
  checkmate::assert_class(page, "pdfium_page")
  if (!is_open(page)) {
    stop("Page has been closed.", call. = FALSE)
  }
  raw <- cpp_text_char_geometry(page$ptr)
  mat <- raw$matrix
  n <- nrow(mat)
  # Split the 6-col matrix into a list-column of length-6 numeric
  # vectors keyed by row.
  rows <- vector("list", n)
  for (i in seq_len(n)) {
    rows[[i]] <- as.numeric(mat[i, ])
  }
  tibble::tibble(
    char_index  = seq_len(n),
    matrix      = rows,
    angle_deg   = raw$angle,
    font_weight = raw$weight
  )
}

# ---- Page-object dash phase + content-mark blob/remove -------------------

#' Set just the dash phase of a path object
#'
#' Wraps `FPDFPageObj_SetDashPhase`. The full dash setter
#' [pdf_path_set_dash()] sets both the array and the phase in one
#' call; this fine-grained setter is useful when you want to tweak
#' the phase without re-supplying the (possibly-long) array.
#'
#' @param path A `pdfium_obj` of `type = "path"`.
#' @param phase Numeric — dash phase in PDF user-space units.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_path_set_dash()] for the array + phase setter.
#' @export
pdf_path_set_dash_phase <- function(path, phase) {
  checkmate::assert_number(phase, finite = TRUE)
  ctx <- assert_obj_writable(path, allowed_types = "path",
                              arg = "path")
  expect_setter_ok(cpp_obj_set_dash_phase(path$ptr,
                                            as.numeric(phase)),
                    "FPDFPageObj_SetDashPhase")
  finalize_obj_setter(ctx)
}

#' Set a binary-blob content-mark parameter
#'
#' Wraps `FPDFPageObjMark_SetBlobParam`. The mark-name + key locate
#' an entry in the page object's marked-content dictionary; the
#' `value` raw vector becomes the entry's binary blob.
#'
#' Use [pdf_obj_mark_remove_param()] for the inverse.
#'
#' @param obj A `pdfium_obj`.
#' @param mark_index One-based index of the mark (per
#'   [pdf_obj_marks()]).
#' @param key Character scalar — the parameter key within the mark.
#' @param value Raw vector — the blob bytes.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_obj_mark_set_blob <- function(obj, mark_index, key, value) {
  checkmate::assert_int(mark_index, lower = 1L)
  checkmate::assert_string(key, min.chars = 1L)
  checkmate::assert_raw(value)
  ctx <- assert_obj_writable(obj, arg = "obj")
  expect_setter_ok(
    cpp_obj_mark_set_blob(ctx$doc$ptr, obj$ptr,
                           as.integer(mark_index) - 1L,
                           key, value),
    "FPDFPageObjMark_SetBlobParam")
  finalize_obj_setter(ctx)
}

#' Remove a content-mark parameter
#'
#' Wraps `FPDFPageObjMark_RemoveParam`. Removes the entry with `key`
#' from the mark identified by `mark_index` (one-based, per
#' [pdf_obj_marks()]).
#'
#' @param obj A `pdfium_obj`.
#' @param mark_index One-based index of the mark.
#' @param key Character scalar — the parameter key to remove.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_obj_mark_remove_param <- function(obj, mark_index, key) {
  checkmate::assert_int(mark_index, lower = 1L)
  checkmate::assert_string(key, min.chars = 1L)
  ctx <- assert_obj_writable(obj, arg = "obj")
  expect_setter_ok(
    cpp_obj_mark_remove_param(obj$ptr,
                                as.integer(mark_index) - 1L, key),
    "FPDFPageObjMark_RemoveParam")
  finalize_obj_setter(ctx)
}

# ---- Font extras: bytes / CIDType2 / charcode-set ------------------------

#' Extract the bytes of an embedded font
#'
#' Wraps `FPDFFont_GetFontData`. Useful for round-tripping an embedded
#' font from one PDF to another, piping into `systemfonts` /
#' `fontmgr`-style introspection, or auditing what's actually been
#' embedded.
#'
#' @param font A `pdfium_font` from [pdf_font_load()],
#'   [pdf_font_load_standard()], or [pdf_text_font()] (the reader
#'   side, which returns the per-text-object font).
#' @return Raw vector of font bytes. `raw(0)` if PDFium reports the
#'   font has no embedded data (e.g. a referenced-only standard font).
#' @export
pdf_font_data <- function(font) {
  checkmate::assert_class(font, "pdfium_font")
  if (!is_open(font)) {
    stop("Font handle has been closed.", call. = FALSE)
  }
  cpp_font_data(font$ptr)
}

#' Load a CID Type 2 (composite TrueType) font with explicit mappings
#'
#' Wraps `FPDFText_LoadCidType2Font`. The CID Type 2 path is a
#' specialisation of [pdf_font_load()] that takes explicit ToUnicode
#' CMap and CID-to-GID mapping tables — useful for embedding fonts
#' whose glyph indexing differs from the default CID identity mapping
#' (e.g. East Asian fonts with custom GID lookups).
#'
#' For ordinary TTF embedding, [pdf_font_load()] with `cid = TRUE` is
#' usually all you need.
#'
#' @param doc A `pdfium_doc` opened with `readwrite = TRUE`.
#' @param font_data Either a raw vector of TTF bytes or a path to a
#'   TTF file on disk.
#' @param to_unicode_cmap Character scalar — the CMap content as a
#'   PostScript-style CMap string. Empty string `""` uses PDFium's
#'   default.
#' @param cid_to_gid Raw vector — the CID-to-GID mapping table
#'   (big-endian uint16 pairs). `raw(0)` uses the identity mapping.
#' @return A `pdfium_font` handle.
#' @seealso [pdf_font_load()] for the simpler TTF path.
#' @export
pdf_font_load_cidtype2 <- function(doc, font_data, to_unicode_cmap = "",
                                    cid_to_gid = raw(0)) {
  assert_readwrite(doc)
  checkmate::assert_string(to_unicode_cmap, na.ok = FALSE)
  checkmate::assert_raw(cid_to_gid)
  bytes <- coerce_font_bytes(font_data)
  ptr <- cpp_font_load_cidtype2(doc$ptr, bytes, to_unicode_cmap,
                                  cid_to_gid)
  display <- if (is.character(font_data)) basename(font_data) else "<raw>"
  new_pdfium_font(ptr, doc, paste0(display, " (CIDType2)"))
}

#' Populate a text object with explicit glyph charcodes
#'
#' Wraps `FPDFText_SetCharcodes`. The standard
#' [pdf_text_set_content()] maps UTF-8 text through the font's CMap
#' to find glyph codes; this lower-level setter takes the codes
#' directly. Useful when the font's encoding is non-standard or when
#' the embedder already has the glyph indices in hand (e.g. from a
#' previous `pdf_text_runs()` extraction).
#'
#' @param obj A `pdfium_obj` of `type = "text"`.
#' @param charcodes Integer vector of unsigned glyph codes. Negative
#'   values raise an error.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_text_set_content()] for the cmap-driven path.
#' @export
pdf_text_set_charcodes <- function(obj, charcodes) {
  checkmate::assert_integerish(charcodes, lower = 0,
                                any.missing = FALSE)
  ctx <- assert_obj_writable(obj, allowed_types = "text", arg = "obj")
  expect_setter_ok(
    cpp_text_set_charcodes(obj$ptr, as.integer(charcodes)),
    "FPDFText_SetCharcodes")
  finalize_obj_setter(ctx)
}

# ===========================================================================
# Phase B — annotation authoring completers.
# ===========================================================================

#' Append an ink stroke to an ink annotation
#'
#' Wraps `FPDFAnnot_AddInkStroke`. The `points` matrix carries the
#' stroke as Nx2 (`x`, `y`) in PDF user-space points; PDFium creates a
#' fresh ink-list entry if the annotation doesn't already have one.
#'
#' @param annot A `pdfium_annot` of subtype `"ink"`.
#' @param points Numeric matrix with two columns (`x`, `y`).
#' @return Invisibly returns the integer stroke index (one-based) of
#'   the newly-added stroke. `-1L` on failure.
#' @seealso [pdf_annot_remove_ink_list()] to clear all strokes.
#' @export
pdf_annot_add_ink_stroke <- function(annot, points) {
  checkmate::assert_matrix(points, mode = "numeric",
                            any.missing = FALSE, min.rows = 1L,
                            ncols = 2L)
  ctx <- assert_annot_writable(annot)
  idx <- cpp_annot_add_ink_stroke(annot$ptr, points)
  if (idx < 0L) {
    stop("FPDFAnnot_AddInkStroke failed; ensure the annotation is ",
         "of subtype 'ink'.", call. = FALSE)
  }
  finalize_annot_setter(ctx)
  invisible(idx + 1L)
}

#' Remove all ink strokes from an ink annotation
#'
#' Wraps `FPDFAnnot_RemoveInkList`. Clears the annotation's entire
#' ink-list array in one call.
#'
#' @param annot A `pdfium_annot` of subtype `"ink"`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_add_ink_stroke()].
#' @export
pdf_annot_remove_ink_list <- function(annot) {
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(cpp_annot_remove_ink_list(annot$ptr),
                    "FPDFAnnot_RemoveInkList")
  finalize_annot_setter(ctx)
}

#' Number of embedded page-objects inside an annotation
#'
#' Wraps `FPDFAnnot_GetObjectCount`. Stamp and FreeText annotations
#' carry their visual content as a small page-object tree;
#' `pdf_annot_object_count()` reports how many top-level objects are
#' inside.
#'
#' @param annot A `pdfium_annot`.
#' @return Integer scalar (zero or positive).
#' @seealso [pdf_annot_objects()], [pdf_annot_append_object()].
#' @export
pdf_annot_object_count <- function(annot) {
  checkmate::assert_class(annot, "pdfium_annot")
  if (!is_open(annot)) {
    stop("Annotation handle has been closed.", call. = FALSE)
  }
  cpp_annot_object_count(annot$ptr)
}

#' Page-objects embedded inside an annotation
#'
#' Wraps `FPDFAnnot_GetObject` over the full count. Returns a list of
#' `pdfium_obj` handles; each handle's externalptr pins the parent
#' annotation, so the embedded objects can't dangle past the annot's
#' lifetime.
#'
#' @param annot A `pdfium_annot`.
#' @return A list of `pdfium_obj` handles (zero-length when the
#'   annotation has no embedded objects).
#' @seealso [pdf_annot_object_count()], [pdf_annot_append_object()].
#' @export
pdf_annot_objects <- function(annot) {
  checkmate::assert_class(annot, "pdfium_annot")
  if (!is_open(annot)) {
    stop("Annotation handle has been closed.", call. = FALSE)
  }
  n <- cpp_annot_object_count(annot$ptr)
  if (n <= 0L) {
    return(list())
  }
  out <- vector("list", n)
  page <- annot$page
  for (i in seq_len(n)) {
    ptr <- cpp_annot_get_object(annot$ptr, i - 1L)
    out[[i]] <- new_pdfium_obj(ptr, page, i, "unknown")
  }
  out
}

#' Append a page-object to an annotation
#'
#' Wraps `FPDFAnnot_AppendObject`. The page-object must be detached
#' (typically created by [pdf_path_new()] / [pdf_rect_new()] /
#' [pdf_text_new()] / [pdf_image_new()] **before** it is inserted into
#' a page). After the call, the annotation owns the page-object —
#' the R-side handle is cleared, so subsequent calls on it error
#' cleanly.
#'
#' @param annot A `pdfium_annot` of subtype `"stamp"` or
#'   `"freetext"`.
#' @param obj A `pdfium_obj`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_annot_append_object <- function(annot, obj) {
  checkmate::assert_class(obj, "pdfium_obj")
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(cpp_annot_append_object(annot$ptr, obj$ptr),
                    "FPDFAnnot_AppendObject")
  finalize_annot_setter(ctx)
}

#' Remove a page-object from an annotation
#'
#' Wraps `FPDFAnnot_RemoveObject`. The object is identified by its
#' position within the annotation's embedded content (one-based,
#' matching [pdf_annot_objects()]).
#'
#' @param annot A `pdfium_annot`.
#' @param index One-based index of the embedded object to remove.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_annot_remove_object <- function(annot, index) {
  checkmate::assert_int(index, lower = 1L)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_remove_object(annot$ptr, as.integer(index) - 1L),
    "FPDFAnnot_RemoveObject")
  finalize_annot_setter(ctx)
}

#' Update an embedded page-object after mutating it
#'
#' Wraps `FPDFAnnot_UpdateObject`. Tells PDFium to re-serialise the
#' annotation's content stream after you've mutated one of the
#' embedded page-objects via the usual `pdf_*_set_*` setters.
#'
#' @param annot A `pdfium_annot`.
#' @param obj A `pdfium_obj` returned by [pdf_annot_objects()].
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_annot_update_object <- function(annot, obj) {
  checkmate::assert_class(obj, "pdfium_obj")
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(cpp_annot_update_object(annot$ptr, obj$ptr),
                    "FPDFAnnot_UpdateObject")
  finalize_annot_setter(ctx)
}

#' Set the URI of a link annotation
#'
#' Wraps `FPDFAnnot_SetURI`. The annotation must be of subtype
#' `"link"`; the URI becomes the link's destination.
#'
#' @param annot A `pdfium_annot` of subtype `"link"`.
#' @param uri Character scalar — the destination URI.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_annot_set_uri <- function(annot, uri) {
  checkmate::assert_string(uri, min.chars = 1L)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(cpp_annot_set_uri(annot$ptr, uri),
                    "FPDFAnnot_SetURI")
  finalize_annot_setter(ctx)
}

# Static table — FPDF_ANNOT_APPEARANCEMODE_* codes from fpdf_annot.h.
.pdfium_appearance_mode_codes <- c(
  "normal"   = 0L,
  "rollover" = 1L,
  "down"     = 2L
)

#' Set the appearance stream content for an annotation
#'
#' Wraps `FPDFAnnot_SetAP`. Replaces the annotation's `/AP`
#' appearance-stream entry for the named mode with the given content
#' string. Pass `""` to clear the entry.
#'
#' @param annot A `pdfium_annot`.
#' @param mode Character scalar — one of `"normal"`, `"rollover"`, or
#'   `"down"`.
#' @param value Character scalar — the appearance-stream content. The
#'   empty string clears the entry.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_appearance()] for the reader counterpart.
#' @export
pdf_annot_set_appearance <- function(annot, mode = "normal",
                                       value = "") {
  checkmate::assert_choice(mode, names(.pdfium_appearance_mode_codes))
  checkmate::assert_string(value, na.ok = FALSE)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_appearance(
      annot$ptr, .pdfium_appearance_mode_codes[[mode]],
      enc2utf8(value)),
    "FPDFAnnot_SetAP")
  finalize_annot_setter(ctx)
}

#' Attach a file to a file-attachment annotation
#'
#' Wraps `FPDFAnnot_AddFileAttachment`. Adds a new file attachment to
#' the document (returning the `pdfium_attachment` handle) and links
#' it to `annot`. Use [pdf_attachment_set_data()] (or the related
#' attachment-authoring setters) to populate the file bytes.
#'
#' @param annot A `pdfium_annot` of subtype `"fileattachment"`.
#' @param name Character scalar — the file name to register in the
#'   document's `/Names` tree.
#' @return The new `pdfium_attachment` handle.
#' @seealso [pdf_attachment_new()] for the doc-level version.
#' @export
pdf_annot_add_file_attachment <- function(annot, name) {
  checkmate::assert_string(name, min.chars = 1L)
  ctx <- assert_annot_writable(annot)
  doc <- ctx$doc
  ptr <- cpp_annot_add_file_attachment(doc$ptr, annot$ptr,
                                         enc2utf8(name))
  finalize_annot_setter(ctx)
  n_att <- cpp_attachment_count(doc$ptr)
  new_pdfium_attachment(ptr, doc, n_att)
}

#' Line endpoints of a line annotation
#'
#' Wraps `FPDFAnnot_GetLine`. PDF line annotations carry their start
#' and end points in `/L` rather than `/Rect`; this helper exposes
#' those endpoints as a named numeric vector.
#'
#' @param annot A `pdfium_annot` of subtype `"line"` (PDFium also
#'   returns endpoints for annotations with a `/L` entry).
#' @return Named numeric vector `c(start_x, start_y, end_x, end_y)`.
#'   All-`NA` when the annotation has no line entry.
#' @export
pdf_annot_line <- function(annot) {
  checkmate::assert_class(annot, "pdfium_annot")
  if (!is_open(annot)) {
    stop("Annotation handle has been closed.", call. = FALSE)
  }
  cpp_annot_line(annot$ptr)
}

#' Link metadata for a link annotation
#'
#' Wraps `FPDFAnnot_GetLink` plus the action/dest classification
#' helpers. Returns a single-row tibble with the same column shape as
#' [pdf_page_links()] (without the rect / quad_points geometry).
#' `NULL` if `annot` has no link entry.
#'
#' @param annot A `pdfium_annot` of subtype `"link"`.
#' @return A 1-row tibble with `action_type`, `uri`, `filepath`,
#'   `dest_page`, `dest_view`, `dest_x`, `dest_y`, `dest_zoom`. `NULL`
#'   if the annotation has no link entry.
#' @seealso [pdf_page_links()] for the page-wide enumeration.
#' @export
pdf_annot_link <- function(annot) {
  checkmate::assert_class(annot, "pdfium_annot")
  if (!is_open(annot)) {
    stop("Annotation handle has been closed.", call. = FALSE)
  }
  raw <- cpp_annot_link_info(annot$page$doc$ptr, annot$ptr)
  if (!isTRUE(raw$found)) return(NULL)
  tibble::tibble(
    action_type = pdfium_action_type_name(raw$action_code),
    uri         = na_if_empty(raw$uri),
    filepath    = na_if_empty(raw$filepath),
    dest_page   = raw$dest_page,
    dest_view   = pdfium_dest_view_name(raw$dest_view),
    dest_x      = raw$dest_x,
    dest_y      = raw$dest_y,
    dest_zoom   = raw$dest_zoom
  )
}

#' Set the border of an annotation
#'
#' Wraps `FPDFAnnot_SetBorder`. The two corner radii produce rounded
#' rectangles when nonzero; `border_width` is the stroke width in
#' PDF user-space units.
#'
#' @param annot A `pdfium_annot`.
#' @param horizontal_radius,vertical_radius Numeric — corner radii in
#'   PDF user-space units. `0` for a square corner.
#' @param border_width Numeric — stroke width in PDF user-space units.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_annot_set_border <- function(annot, horizontal_radius = 0,
                                   vertical_radius = 0,
                                   border_width = 1) {
  checkmate::assert_number(horizontal_radius, lower = 0,
                            finite = TRUE)
  checkmate::assert_number(vertical_radius, lower = 0, finite = TRUE)
  checkmate::assert_number(border_width, lower = 0, finite = TRUE)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_border(annot$ptr,
                          as.numeric(horizontal_radius),
                          as.numeric(vertical_radius),
                          as.numeric(border_width)),
    "FPDFAnnot_SetBorder")
  finalize_annot_setter(ctx)
}

# ===========================================================================
# Phase C — clip-path authoring.
# ===========================================================================

# Internal S3 constructor for pdfium_clip_box. The handle has its
# own finalizer registered C-side (FPDF_DestroyClipPath); no parent
# pinning because PDFium clip paths are standalone (created by
# coordinates, inserted into a page on demand).
new_pdfium_clip_box <- function(ptr, bounds) {
  checkmate::assert_class(ptr, "externalptr", .var.name = "ptr")
  checkmate::assert_numeric(bounds, len = 4L, .var.name = "bounds")
  structure(
    list(ptr = ptr, bounds = bounds),
    class = c("pdfium_clip_box", "pdfium_handle")
  )
}

#' @export
format.pdfium_clip_box <- function(x, ...) {
  state <- if (cpp_handle_is_valid(x$ptr)) "open" else "closed"
  sprintf(
    "<pdfium_clip_box [%s] left=%g bottom=%g right=%g top=%g>",
    state, x$bounds[[1L]], x$bounds[[2L]],
    x$bounds[[3L]], x$bounds[[4L]]
  )
}

#' @export
print.pdfium_clip_box <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

#' Create a clip path covering a rectangle
#'
#' Wraps `FPDF_CreateClipPath`. Returns a `pdfium_clip_box` handle
#' that can be inserted into a page via [pdf_page_insert_clip_path()]
#' to restrict the page's rendered output to the given rectangle.
#'
#' @param bounds Numeric length-4 vector `c(left, bottom, right, top)`
#'   in PDF user-space points.
#' @return A `pdfium_clip_box` handle. The handle carries an
#'   `FPDF_DestroyClipPath` finalizer; explicit [pdf_clip_path_close()]
#'   is optional but useful for deterministic release.
#' @seealso [pdf_page_insert_clip_path()],
#'   [pdf_obj_transform_clip_path()],
#'   [pdf_page_transform_with_clip()].
#' @examples
#' \dontrun{
#' doc <- pdf_doc_new()
#' page <- pdf_page_new(doc, width = 612, height = 792)
#' cp <- pdf_clip_path_new(c(72, 72, 540, 720))
#' pdf_page_insert_clip_path(page, cp)
#' pdf_save(doc, tempfile(fileext = ".pdf"))
#' }
#' @export
pdf_clip_path_new <- function(bounds) {
  checkmate::assert_numeric(bounds, len = 4L, any.missing = FALSE,
                             finite = TRUE)
  ptr <- cpp_clip_path_new(as.numeric(bounds[[1L]]),
                             as.numeric(bounds[[2L]]),
                             as.numeric(bounds[[3L]]),
                             as.numeric(bounds[[4L]]))
  new_pdfium_clip_box(ptr, as.numeric(bounds))
}

#' Release a clip-path handle
#'
#' Wraps `FPDF_DestroyClipPath`. Idempotent — a second call is a
#' no-op. The finalizer attached to the externalptr also runs this
#' when R garbage-collects the handle; explicit close is useful when
#' you've created many clip paths and want deterministic release.
#'
#' @param clip_path A `pdfium_clip_box` from [pdf_clip_path_new()].
#' @return Invisibly returns `clip_path`.
#' @export
pdf_clip_path_close <- function(clip_path) {
  checkmate::assert_class(clip_path, "pdfium_clip_box")
  cpp_clip_path_close(clip_path$ptr)
  invisible(clip_path)
}

#' Insert a clip path into a page
#'
#' Wraps `FPDFPage_InsertClipPath`. After insertion the clip path is
#' owned by the page; the R-side `pdfium_clip_box` handle's
#' externalptr is cleared automatically so subsequent operations on
#' it error cleanly via `is_open()`.
#'
#' @param page A `pdfium_page` from [pdf_page_load()] or
#'   [pdf_page_new()]. Parent doc must be readwrite.
#' @param clip_path A `pdfium_clip_box` from [pdf_clip_path_new()].
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_clip_path_new()], [pdf_page_transform_with_clip()].
#' @export
pdf_page_insert_clip_path <- function(page, clip_path) {
  checkmate::assert_class(clip_path, "pdfium_clip_box")
  if (!cpp_handle_is_valid(clip_path$ptr)) {
    stop("Clip-path handle has been closed.", call. = FALSE)
  }
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  cpp_page_insert_clip_path(ph$page$ptr, clip_path$ptr)
  mark_page_dirty(ph$doc, ph$page$index)
  invisible(ph$doc)
}

#' Transform the clip path of a page object
#'
#' Wraps `FPDFPageObj_TransformClipPath`. Applies a 6-tuple affine
#' transform `(a, b, c, d, e, f)` to the existing clip path of a
#' page object — useful for scaling / rotating / translating a
#' previously-set clip without rebuilding it.
#'
#' @param obj A `pdfium_obj` with an existing clip path.
#' @param matrix Numeric length-6 vector `c(a, b, c, d, e, f)`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_obj_transform_clip_path <- function(obj, matrix) {
  checkmate::assert_numeric(matrix, len = 6L, any.missing = FALSE,
                             finite = TRUE)
  ctx <- assert_obj_writable(obj, arg = "obj")
  cpp_obj_transform_clip_path(obj$ptr,
                                matrix[[1L]], matrix[[2L]],
                                matrix[[3L]], matrix[[4L]],
                                matrix[[5L]], matrix[[6L]])
  finalize_obj_setter(ctx)
}

#' Apply a transform to a page's content stream with an optional clip
#'
#' Wraps `FPDFPage_TransFormWithClip`. The matrix is applied to the
#' entire page content; when `clip_rect` is supplied (length-4 numeric
#' `c(left, bottom, right, top)`), the page is clipped to that
#' rectangle after the transform.
#'
#' @param page A `pdfium_page` or `pdfium_doc`.
#' @param matrix Numeric length-6 vector `c(a, b, c, d, e, f)`.
#' @param clip_rect Optional numeric length-4 vector
#'   `c(left, bottom, right, top)`. `NULL` means no clip.
#' @param page_num Used when `page` is a `pdfium_doc`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_page_transform_with_clip <- function(page, matrix,
                                           clip_rect = NULL,
                                           page_num = 1L) {
  checkmate::assert_numeric(matrix, len = 6L, any.missing = FALSE,
                             finite = TRUE)
  if (!is.null(clip_rect)) {
    checkmate::assert_numeric(clip_rect, len = 4L,
                               any.missing = FALSE, finite = TRUE)
  }
  ph <- as_page_and_doc(page, page_num)
  assert_readwrite(ph$doc)
  rect_arg <- if (is.null(clip_rect)) numeric(0) else as.numeric(clip_rect)
  expect_setter_ok(
    cpp_page_transform_with_clip(ph$page$ptr,
                                   as.numeric(matrix), rect_arg),
    "FPDFPage_TransFormWithClip")
  mark_page_dirty(ph$doc, ph$page$index)
  invisible(ph$doc)
}

# ===========================================================================
# Phase D — form-XObject / page-merge extras.
# ===========================================================================

# Internal pdfium_xobject constructor. The FPDF_XOBJECT handle has
# its own lifetime (FPDF_CloseXObject); the externalptr's prot
# slot pins the destination doc.
new_pdfium_xobject <- function(ptr, doc, source_label) {
  checkmate::assert_class(ptr, "externalptr", .var.name = "ptr")
  checkmate::assert_class(doc, "pdfium_doc", .var.name = "doc")
  checkmate::assert_string(source_label, .var.name = "source_label")
  structure(
    list(ptr = ptr, doc = doc, source = source_label),
    class = c("pdfium_xobject", "pdfium_handle")
  )
}

#' @export
format.pdfium_xobject <- function(x, ...) {
  state <- if (cpp_handle_is_valid(x$ptr)) "open" else "closed"
  sprintf("<pdfium_xobject [%s] from %s>", state, x$source)
}

#' @export
print.pdfium_xobject <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

#' Create an XObject (reusable form) from a source-doc page
#'
#' Wraps `FPDF_NewXObjectFromPage`. Copies the visual content of
#' `src_doc`'s page `src_page_num` into `dest_doc` as an
#' `FPDF_XOBJECT`. The XObject can then be instantiated multiple
#' times in `dest_doc` via [pdf_obj_form_from_xobject()] — useful
#' for "n-up" layouts where the same page content needs to be tiled.
#'
#' @param dest_doc A `pdfium_doc` opened with `readwrite = TRUE`.
#' @param src_doc Source `pdfium_doc`. Read-only is fine.
#' @param src_page_num One-based page index in `src_doc`.
#' @return A `pdfium_xobject` handle.
#' @seealso [pdf_obj_form_from_xobject()] to instantiate as a page
#'   object; [pdf_xobject_close()] for deterministic release.
#' @export
pdf_xobject_from_page <- function(dest_doc, src_doc, src_page_num = 1L) {
  assert_readwrite(dest_doc)
  checkmate::assert_class(src_doc, "pdfium_doc")
  if (!is_open(src_doc)) {
    stop("Source document has been closed.", call. = FALSE)
  }
  checkmate::assert_int(src_page_num, lower = 1L)
  ptr <- cpp_xobject_from_page(dest_doc$ptr, src_doc$ptr,
                                 as.integer(src_page_num) - 1L)
  label <- sprintf("%s page %d", basename(src_doc$path),
                    src_page_num)
  new_pdfium_xobject(ptr, dest_doc, label)
}

#' Close an XObject handle
#'
#' Wraps `FPDF_CloseXObject`. Idempotent. Closing the XObject does
#' NOT invalidate page-objects created from it via
#' [pdf_obj_form_from_xobject()] — those are owned by their parent
#' page and survive the XObject's release.
#'
#' @param xobject A `pdfium_xobject` from [pdf_xobject_from_page()].
#' @return Invisibly returns `xobject`.
#' @export
pdf_xobject_close <- function(xobject) {
  checkmate::assert_class(xobject, "pdfium_xobject")
  cpp_xobject_close(xobject$ptr)
  invisible(xobject)
}

#' Instantiate an XObject as a form page-object on a page
#'
#' Wraps `FPDF_NewFormObjectFromXObject` + `FPDFPage_InsertObject`.
#' Creates a fresh form-xobject page-object referencing the shared
#' XObject content and inserts it on `page`. The page-object can
#' then be transformed / placed via the usual
#' [pdf_obj_set_matrix()] setter.
#'
#' @param page A `pdfium_page` from [pdf_page_new()] or
#'   [pdf_page_load()] (parent doc must be readwrite).
#' @param xobject A `pdfium_xobject` from [pdf_xobject_from_page()].
#'   The XObject must have been created against the same `dest_doc`
#'   that owns `page`.
#' @return The new `pdfium_obj` (type `"form"`).
#' @seealso [pdf_xobject_from_page()].
#' @export
pdf_obj_form_from_xobject <- function(page, xobject) {
  checkmate::assert_class(xobject, "pdfium_xobject")
  if (!cpp_handle_is_valid(xobject$ptr)) {
    stop("XObject handle has been closed.", call. = FALSE)
  }
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  obj_ptr <- cpp_form_obj_from_xobject(xobject$ptr)
  # cpp_form_obj_from_xobject returns a detached page-object. Insert
  # via cpp_page_insert_object (already wrapped for the existing
  # creators).
  cpp_page_insert_object(ph$page$ptr, obj_ptr)
  idx <- cpp_page_object_count(ph$page$ptr)
  mark_page_dirty(ph$doc, ph$page$index)
  new_pdfium_obj(obj_ptr, ph$page, idx, "form")
}

#' Remove a child page-object from a form-xobject
#'
#' Wraps `FPDFFormObj_RemoveObject`. The child must currently belong
#' to the form-xobject. After removal the child's R-side externalptr
#' is unchanged (PDFium destroys the child internally); calling other
#' setters on the same handle will error cleanly via the existing
#' `is_open()` chain because PDFium's pointer is no longer valid.
#'
#' @param form_obj A `pdfium_obj` of `type = "form"`.
#' @param child A `pdfium_obj` from [pdf_form_objects()] (the
#'   enumeration of children).
#' @return Invisibly returns the parent `pdfium_doc`.
#' @export
pdf_form_obj_remove_object <- function(form_obj, child) {
  checkmate::assert_class(child, "pdfium_obj")
  ctx <- assert_obj_writable(form_obj, allowed_types = "form",
                              arg = "form_obj")
  expect_setter_ok(
    cpp_form_obj_remove_child(form_obj$ptr, child$ptr),
    "FPDFFormObj_RemoveObject")
  finalize_obj_setter(ctx)
}

#' Import page ranges from a source doc into a destination doc
#'
#' Wraps `FPDF_ImportPages` — the string-range variant of
#' [pdf_docs_merge()]. Takes a comma-separated range like
#' `"1-3,5,7-10"` instead of an integer vector.
#'
#' @param dest_doc A `pdfium_doc` opened with `readwrite = TRUE`.
#' @param src_doc Source `pdfium_doc`.
#' @param range Character — the page range. Empty string `""` (the
#'   default) imports every page.
#' @param at One-based insertion index in `dest_doc`. Defaults to the
#'   end (use `pdf_page_count(dest_doc) + 1`).
#' @return Invisibly returns `dest_doc`.
#' @seealso [pdf_docs_merge()] for the integer-vector variant.
#' @export
pdf_docs_import_pages <- function(dest_doc, src_doc, range = "",
                                    at = NULL) {
  assert_readwrite(dest_doc)
  checkmate::assert_class(src_doc, "pdfium_doc")
  if (!is_open(src_doc)) {
    stop("Source document has been closed.", call. = FALSE)
  }
  checkmate::assert_string(range, na.ok = FALSE)
  if (is.null(at)) {
    at <- pdf_page_count(dest_doc) + 1L
  }
  checkmate::assert_int(at, lower = 1L)
  expect_setter_ok(
    cpp_doc_import_pages_string(dest_doc$ptr, src_doc$ptr, range,
                                  as.integer(at) - 1L),
    "FPDF_ImportPages")
  invisible(dest_doc)
}

# ===========================================================================
# Phase E — image-bitmap embedding (FPDF_BITMAP lifecycle).
# ===========================================================================

# Internal pdfium_bitmap constructor. The handle has its own
# finalizer (FPDFBitmap_Destroy); no parent pinning because bitmaps
# are standalone — they only become associated with a doc / page
# when set on an image object via pdf_image_set_bitmap().
new_pdfium_image_buffer <- function(ptr, width, height, alpha) {
  checkmate::assert_class(ptr, "externalptr", .var.name = "ptr")
  structure(
    list(ptr = ptr, width = width, height = height, alpha = alpha),
    class = c("pdfium_image_buffer", "pdfium_handle")
  )
}

#' @export
format.pdfium_image_buffer <- function(x, ...) {
  state <- if (cpp_handle_is_valid(x$ptr)) "open" else "closed"
  sprintf("<pdfium_image_buffer [%s] %dx%d %s>",
           state, x$width, x$height,
           if (x$alpha) "BGRA" else "BGRx")
}

#' @export
print.pdfium_image_buffer <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

#' Create a fresh in-memory bitmap
#'
#' Wraps `FPDFBitmap_Create`. Allocates a `width × height` bitmap
#' that can be populated via [pdf_bitmap_fill_rect()] or
#' [pdf_bitmap_set_buffer()] and then attached to an image page-
#' object via [pdf_image_set_bitmap()]. This is the v0.1.0 path for
#' embedding non-JPEG (PNG / TIFF / raw raster) images into a PDF.
#'
#' Pixel layout:
#'   * `alpha = TRUE`: BGRA, 4 bytes per pixel, top-down rows.
#'   * `alpha = FALSE`: BGRx, 4 bytes per pixel with the 4th byte
#'     unused.
#'
#' @param width,height Integer — pixel dimensions. Must be positive.
#' @param alpha Logical. If `TRUE` (default), the bitmap has an
#'   alpha channel.
#' @return A `pdfium_image_buffer` handle.
#' @seealso [pdf_bitmap_close()], [pdf_image_set_bitmap()],
#'   [pdf_bitmap_fill_rect()], [pdf_bitmap_set_buffer()].
#' @export
pdf_bitmap_new <- function(width, height, alpha = TRUE) {
  checkmate::assert_int(width, lower = 1L)
  checkmate::assert_int(height, lower = 1L)
  checkmate::assert_flag(alpha)
  ptr <- cpp_bitmap_new(as.integer(width), as.integer(height), alpha)
  new_pdfium_image_buffer(ptr, as.integer(width), as.integer(height),
                      alpha)
}

#' Release a bitmap handle
#'
#' Wraps `FPDFBitmap_Destroy`. Idempotent. After
#' [pdf_image_set_bitmap()] has attached the bitmap to a page-object,
#' explicit close is safe (PDFium has copied the pixel data into the
#' PDF — closing only releases the standalone in-memory bitmap, not
#' the embedded image).
#'
#' @param bitmap A `pdfium_image_buffer`.
#' @return Invisibly returns `bitmap`.
#' @export
pdf_bitmap_close <- function(bitmap) {
  checkmate::assert_class(bitmap, "pdfium_image_buffer")
  cpp_bitmap_close(bitmap$ptr)
  invisible(bitmap)
}

#' Bitmap dimensions and format
#'
#' Wraps `FPDFBitmap_GetWidth`, `_GetHeight`, `_GetStride`, and
#' `_GetFormat`. Returns a list with the bitmap's pixel layout
#' (width × height) plus stride in bytes and the PDFium format code.
#'
#' Format codes (from `fpdfview.h`'s `FPDFBitmap_*` macros):
#'   * `1` = Gray (1 byte/pixel)
#'   * `2` = BGR (3 bytes/pixel)
#'   * `3` = BGRx (4 bytes/pixel, 4th byte unused)
#'   * `4` = BGRA (4 bytes/pixel with alpha)
#'
#' @param bitmap A `pdfium_image_buffer`.
#' @return Named list — `width`, `height`, `stride`, `format`.
#' @export
pdf_bitmap_info <- function(bitmap) {
  checkmate::assert_class(bitmap, "pdfium_image_buffer")
  if (!cpp_handle_is_valid(bitmap$ptr)) {
    stop("Bitmap handle has been closed.", call. = FALSE)
  }
  cpp_bitmap_info(bitmap$ptr)
}

#' Fill a rectangle of the bitmap with a solid color
#'
#' Wraps `FPDFBitmap_FillRect`. Coordinate origin is the top-left
#' pixel (0, 0). Color is encoded as the integer `0xAARRGGBB`.
#'
#' @param bitmap A `pdfium_image_buffer`.
#' @param left,top,width,height Integer — rectangle in bitmap pixels.
#' @param color Integer — color as `0xAARRGGBB`. Use
#'   `bitmap_color(r, g, b, a)` for a friendly constructor.
#' @return Invisibly returns `bitmap`.
#' @export
pdf_bitmap_fill_rect <- function(bitmap, left, top, width, height,
                                   color) {
  checkmate::assert_class(bitmap, "pdfium_image_buffer")
  if (!cpp_handle_is_valid(bitmap$ptr)) {
    stop("Bitmap handle has been closed.", call. = FALSE)
  }
  checkmate::assert_int(left)
  checkmate::assert_int(top)
  checkmate::assert_int(width, lower = 0L)
  checkmate::assert_int(height, lower = 0L)
  checkmate::assert_number(color, finite = TRUE)
  expect_setter_ok(
    cpp_bitmap_fill_rect(bitmap$ptr,
                          as.integer(left), as.integer(top),
                          as.integer(width), as.integer(height),
                          as.numeric(color)),
    "FPDFBitmap_FillRect")
  invisible(bitmap)
}

#' Read or write the bitmap's raw pixel bytes
#'
#' [pdf_bitmap_buffer()] returns a raw vector of length
#' `stride * height` containing the bitmap's pixel data exactly as
#' PDFium stores it. [pdf_bitmap_set_buffer()] writes a raw vector
#' of the same length into the bitmap (length is checked).
#'
#' The byte order depends on the format reported by
#' [pdf_bitmap_info()]. For BGRA the i'th pixel at row `r`, col `c`
#' is `buf[stride * r + 4 * c + 1:4] == c(B, G, R, A)`.
#'
#' @param bitmap A `pdfium_image_buffer`.
#' @param bytes For [pdf_bitmap_set_buffer()] — a raw vector of
#'   length `stride * height`.
#' @return [pdf_bitmap_buffer()] returns a raw vector;
#'   [pdf_bitmap_set_buffer()] returns `bitmap` invisibly.
#' @rdname pdf_bitmap_buffer
#' @export
pdf_bitmap_buffer <- function(bitmap) {
  checkmate::assert_class(bitmap, "pdfium_image_buffer")
  if (!cpp_handle_is_valid(bitmap$ptr)) {
    stop("Bitmap handle has been closed.", call. = FALSE)
  }
  cpp_bitmap_buffer(bitmap$ptr)
}

#' @rdname pdf_bitmap_buffer
#' @export
pdf_bitmap_set_buffer <- function(bitmap, bytes) {
  checkmate::assert_class(bitmap, "pdfium_image_buffer")
  if (!cpp_handle_is_valid(bitmap$ptr)) {
    stop("Bitmap handle has been closed.", call. = FALSE)
  }
  checkmate::assert_raw(bytes)
  expect_setter_ok(cpp_bitmap_set_buffer(bitmap$ptr, bytes),
                    "cpp_bitmap_set_buffer")
  invisible(bitmap)
}

#' Set a bitmap on an image page-object
#'
#' Wraps `FPDFImageObj_SetBitmap`. PDFium copies the bitmap's pixel
#' data into the document immediately; closing the `bitmap` handle
#' afterward is safe (and recommended for deterministic release).
#'
#' Typical workflow:
#' ```r
#' bm <- pdf_bitmap_new(width = 100, height = 100)
#' pdf_bitmap_set_buffer(bm, my_bgra_bytes)
#' img <- pdf_image_new(page, jpeg = raw(0), bounds = c(0, 0, 200, 200))
#' pdf_image_set_bitmap(img, bm)
#' pdf_bitmap_close(bm)
#' ```
#'
#' @param image A `pdfium_obj` of `type = "image"`.
#' @param bitmap A `pdfium_image_buffer`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_image_new()] for the JPEG-only path that doesn't
#'   require a bitmap.
#' @export
pdf_image_set_bitmap <- function(image, bitmap) {
  checkmate::assert_class(bitmap, "pdfium_image_buffer")
  if (!cpp_handle_is_valid(bitmap$ptr)) {
    stop("Bitmap handle has been closed.", call. = FALSE)
  }
  ctx <- assert_obj_writable(image, allowed_types = "image",
                              arg = "image")
  expect_setter_ok(cpp_image_set_bitmap(image$ptr, bitmap$ptr),
                    "FPDFImageObj_SetBitmap")
  finalize_obj_setter(ctx)
}

# ===========================================================================
# Phase G — system font integration (inspectable surface only).
# ===========================================================================

#' PDFium's default charset → TTF substitution map
#'
#' Wraps `FPDF_GetDefaultTTFMapCount` + `FPDF_GetDefaultTTFMapEntry`.
#' Returns the static "PDF charset code → TrueType font name"
#' substitution table PDFium ships with the build. When a PDF
#' references a font by charset code only (e.g. `/Encoding /WinAnsi`
#' with no /BaseFont resolution), PDFium consults this table to
#' decide which TTF to fall back to.
#'
#' Useful for auditing why a particular missing-glyph PDF rendered
#' with a substitute font, and for confirming which charsets PDFium
#' can serve without an explicit `pdf_font_load()`.
#'
#' @return A tibble with columns `charset` (integer code) and
#'   `fontname` (character).
#' @seealso [pdf_system_fonts_install_default()] to install the
#'   platform's default sys-font-info provider so the substitution
#'   actually fires.
#' @export
pdf_system_fonts_default_ttf_map <- function() {
  n <- cpp_default_ttf_map_size()
  if (n <= 0L) {
    return(tibble::tibble(charset = integer(0),
                            fontname = character(0)))
  }
  charset <- integer(n)
  fontname <- character(n)
  for (i in seq_len(n)) {
    e <- cpp_default_ttf_map_entry(i - 1L)
    charset[[i]] <- as.integer(e$charset)
    fontname[[i]] <- e$fontname
  }
  tibble::tibble(charset = charset, fontname = fontname)
}

#' Install PDFium's default system-font-info provider
#'
#' Wraps `FPDF_SetSystemFontInfo(FPDF_GetDefaultSystemFontInfo())`.
#' Tells PDFium to use the platform's default callback table for
#' resolving font requests against installed system fonts. Without
#' this, PDFium falls back to its built-in (static) substitution
#' table only — which is fine for most documents but misses
#' platform-installed typefaces.
#'
#' Idempotent across calls; the provider persists for the package's
#' lifetime (PDFium retains the pointer; we don't call
#' `FPDF_FreeDefaultSystemFontInfo` because the provider is
#' library-global).
#'
#' Custom providers (R-side callbacks for font enumeration) are
#' deferred to a later release — they require marshalling
#' `FPDF_SYSFONTINFO`'s callback table into R closures, which is
#' non-trivial.
#'
#' @return Invisibly returns `TRUE` if the provider was installed,
#'   `FALSE` if the platform has no default provider (e.g.
#'   stripped-down builds).
#' @export
pdf_system_fonts_install_default <- function() {
  ok <- cpp_install_default_sysfont_info()
  invisible(ok)
}

# ===========================================================================
# The three FFL-env-requiring setters PDFium exposes — these need an
# FPDFDOC_InitFormFillEnvironment call before, and Exit after, the
# Set call itself. The Rcpp ScopedFormHandle helper in
# src/api_completion.cpp owns the lifetime (init / exit) so the
# FPDF_FORMFILLINFO struct outlives the env handle (PDFium stores a
# pointer to FORMFILLINFO internally and dereferences it on Exit; a
# constructor-local would dangle and segfault — found via gdb,
# see dev/reprex/ for the diagnostic story).

#' Set the doc-wide list of annotation subtypes that participate in
#' tab focus
#'
#' Wraps `FPDFAnnot_SetFocusableSubtypes`. Pair with the existing
#' [pdf_doc_focusable_subtypes()] reader.
#'
#' @param doc A `pdfium_doc` opened with `readwrite = TRUE`.
#' @param subtypes Character vector of subtype names (e.g.
#'   `c("widget", "link")`). Must match the subtype-code table used
#'   by [pdfium_annot_subtype_code()].
#' @return Invisibly returns `doc`.
#' @seealso [pdf_doc_focusable_subtypes()].
#' @export
pdf_doc_set_focusable_subtypes <- function(doc, subtypes) {
  assert_readwrite(doc)
  checkmate::assert_character(subtypes, any.missing = FALSE,
                               min.len = 0L)
  codes <- pdfium_annot_subtype_code(subtypes)
  expect_setter_ok(
    cpp_annot_set_focusable_subtypes(doc$ptr, as.integer(codes)),
    "FPDFAnnot_SetFocusableSubtypes")
  invisible(doc)
}

#' Set the font color of an annotation
#'
#' Wraps `FPDFAnnot_SetFontColor`. Routes through a transient form-
#' fill environment per PDFium's API.
#'
#' @param annot A `pdfium_annot` (typically of subtype `"freetext"`
#'   or a widget — PDFium silently ignores the call on subtypes
#'   that don't carry a font).
#' @param color Numeric length-3 vector `c(R, G, B)` with values in
#'   `0:255`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_annot_font_color()] for the reader counterpart.
#' @export
pdf_annot_set_font_color <- function(annot, color) {
  checkmate::assert_integerish(color, lower = 0, upper = 255,
                                 len = 3L, any.missing = FALSE)
  ctx <- assert_annot_writable(annot)
  expect_setter_ok(
    cpp_annot_set_font_color(ctx$doc$ptr, annot$ptr,
                               as.integer(color[[1L]]),
                               as.integer(color[[2L]]),
                               as.integer(color[[3L]])),
    "FPDFAnnot_SetFontColor")
  finalize_annot_setter(ctx)
}

#' Set the form-field flag bitmask on a form-field widget
#'
#' Wraps `FPDFAnnot_SetFormFieldFlags`. Pair with the existing
#' [pdf_form_field_flags()] reader.
#'
#' @param field A `pdfium_form_field` from [pdf_form_fields()].
#' @param flags Integer bitmask of `FPDF_FORMFLAG_*` values.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_form_field_flags()].
#' @export
pdf_form_field_set_flags <- function(field, flags) {
  checkmate::assert_class(field, "pdfium_form_field")
  checkmate::assert_int(flags, lower = 0)
  doc <- field$page$doc
  assert_readwrite(doc)
  if (!is_open(field)) {
    stop("Form-field handle has been closed.", call. = FALSE)
  }
  expect_setter_ok(
    cpp_annot_set_form_field_flags(doc$ptr, field$ptr,
                                     as.integer(flags)),
    "FPDFAnnot_SetFormFieldFlags")
  mark_page_dirty(doc, field$page$index)
  invisible(doc)
}
