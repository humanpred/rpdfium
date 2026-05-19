#' Font size of a text page-object
#'
#' Returns the typographic ("em") font size, in PDF points, set on
#' the text object. This is the raw size stored in the PDF; it is
#' NOT scaled by the object's transformation matrix. PDF producers
#' often emit text at em-size `1` and let the CTM do the scaling
#' (Cairo's PDF backend works that way). To recover the on-page
#' rendered size, multiply this value by the y-scale of the
#' object's matrix (the matrix accessor lands in a later phase).
#'
#' @param obj A `pdfium_obj` of type `"text"` (from
#'   [pdf_page_objects()]).
#' @return Numeric scalar in PDF points, or `NA_real_` if PDFium
#'   reports no font size (rare; usually only for malformed PDFs).
#'
#' @seealso [pdf_page_objects()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(p))[[1]]
#'   pdf_text_font_size(text_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_text_font_size <- function(obj) {
  check_text_obj(obj)
  cpp_text_font_size(obj$ptr)
}

#' Text content of a text page-object
#'
#' Returns the Unicode text of `obj` as a single character string.
#' PDFium produces UTF-16LE internally; the wrapper converts to
#' UTF-8 with the encoding flag set so R prints non-ASCII glyphs
#' correctly.
#'
#' Loading text from a PDF requires the per-page text-extraction
#' context (`FPDFText_LoadPage` / `FPDFText_ClosePage`). The wrapper
#' opens and closes that context internally on every call. When you
#' need many text objects from one page, the upcoming
#' `pdf_text_runs()` (Phase 3 slice 2) will share a single text-page
#' across the entire page to avoid the per-call overhead.
#'
#' @param obj A `pdfium_obj` of type `"text"` (from
#'   [pdf_page_objects()]).
#' @return A character scalar (UTF-8 encoded). An empty text object
#'   returns `""`.
#'
#' @seealso [pdf_text_font_size()], [pdf_page_objects()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(p))[[1]]
#'   pdf_text_content(text_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_text_content <- function(obj) {
  check_text_obj(obj)
  cpp_text_content(obj$ptr)
}

#' Extract every text run on a page
#'
#' Returns one row per text page-object on `page`, with the text
#' content, bounding box, font size, and 1-based page-object index.
#' Loads PDFium's per-page text-extraction context
#' (`FPDFText_LoadPage`) once and reuses it across every text
#' object on the page; this is materially faster than calling
#' [pdf_text_content()] in a loop, which opens and closes a text
#' page per object.
#'
#' The returned tibble's schema matches the `text_runs` attribute
#' produced by [pdf_extract_paths()].
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc` (in which case the first page is loaded and
#'   closed automatically).
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A tibble with columns:
#'   * `obj_index` - 1-based page-object index (so this row is the
#'     `obj_index`-th object returned by [pdf_page_objects()]).
#'     Renamed from `text_index` in the v0.1.0 reader/writer audit
#'     to avoid colliding with `pdf_text_chars()$text_index`, which
#'     is the *extractable-text* offset.
#'   * `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top`
#'     - the object's bounding box in PDF points
#'   * `font_size` - typographic em size; multiply by the text
#'     object's matrix scale (when available) for rendered size
#'   * `text` - UTF-8 string
#'
#' @seealso [pdf_text_content()], [pdf_extract_paths()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "unicode.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   pdf_text_runs(doc, 1)
#'   pdf_close(doc)
#' }
#' @export
pdf_text_runs <- function(page, page_num = 1L) {
  ph <- as_open_page(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  raw <- cpp_page_text_runs(ph$page$ptr)
  # `obj_index` is the page-object index PDFium reports (1-based,
  # spans all page objects on the page — paths, images, text). The
  # column was previously called `text_index` but that name collided
  # with `pdf_text_chars()$text_index` (the *extractable-text*
  # offset). Renamed during the v0.1.0 reader/writer audit; see the
  # audit doc under the dev directory for the rationale.
  tibble::tibble(
    obj_index         = raw$text_index,
    bounds_left       = raw$bounds_left,
    bounds_bottom     = raw$bounds_bottom,
    bounds_right      = raw$bounds_right,
    bounds_top        = raw$bounds_top,
    font_size         = raw$font_size,
    text              = raw$text,
    font_base_name    = raw$font_base_name,
    font_family       = raw$font_family,
    font_weight       = raw$font_weight,
    font_italic_angle = raw$font_italic_angle,
    font_is_embedded  = raw$font_is_embedded,
    font_flags        = raw$font_flags
  )
}

#' Font metadata of a text page-object
#'
#' Returns the font properties PDFium exposes for `obj`'s text: the
#' base font name (e.g. "Helvetica-Bold"), the family name (e.g.
#' "Helvetica"), weight (typographic weight integer, 400 = regular,
#' 700 = bold), italic angle in degrees (negative for italic
#' slant), whether the font is embedded in the PDF, and the PDF
#' font-descriptor flags bitmask (see PDF spec section "Font
#' Descriptors", Table 123).
#'
#' If the text object has no font set (rare; usually only for
#' malformed PDFs), every field is `NA`.
#'
#' @param obj A `pdfium_obj` of type `"text"` (from
#'   [pdf_page_objects()]).
#' @return A named list with elements (matching the `font_*` columns
#'   that [pdf_text_runs()] returns for the same text object, so
#'   either shape can feed directly into a row of the other):
#'   * `font_base_name` - character scalar, base font name; UTF-8
#'   * `font_family` - character scalar, font family name; UTF-8
#'   * `font_weight` - integer (e.g. 400, 500, 700)
#'   * `font_italic_angle` - integer degrees; 0 for upright
#'   * `font_is_embedded` - logical
#'   * `font_flags` - integer bitmask
#'
#' @seealso [pdf_text_content()], [pdf_text_runs()],
#'   [pdf_text_font_size()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(p))[[1]]
#'   pdf_text_font(text_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_text_font <- function(obj) {
  check_text_obj(obj)
  raw <- cpp_text_font(obj$ptr)
  list(
    font_base_name    = raw$base_name,
    font_family       = raw$family,
    font_weight       = raw$weight,
    font_italic_angle = raw$italic_angle,
    font_is_embedded  = raw$is_embedded,
    font_flags        = raw$flags
  )
}

# Internal: validate that `obj` is an open pdfium_obj of type "text".
# Centralised so the input-validation message stays in one place.
check_text_obj <- function(obj) {
  check_pdfium_obj(obj, allowed_types = "text")
}
