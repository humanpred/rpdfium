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
#'   [pdf_page_annotations()].
#' @return Integer scalar — one-based annotation index on the parent
#'   page, or `NA_integer_` if the annotation is not found.
#' @seealso [pdf_page_annotations()].
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
  checkmate::assert_int(start_x); checkmate::assert_int(start_y)
  checkmate::assert_int(size_x, lower = 1L)
  checkmate::assert_int(size_y, lower = 1L)
  checkmate::assert_choice(rotate, c(0L, 1L, 2L, 3L))
  checkmate::assert_int(device_x); checkmate::assert_int(device_y)
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
  checkmate::assert_int(start_x); checkmate::assert_int(start_y)
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
