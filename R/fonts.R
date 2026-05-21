# Font loading + handle class for the page-authoring API.
#
# Three constructors:
#   * pdf_font_load_standard(doc, name)   — one of the 14 PDF standard
#     Type 1 fonts. No bytes needed.
#   * pdf_font_load(doc, font_data, type) — TTF / Type1 bytes, embedded
#     into the PDF.
#   * (internal) new_pdfium_font(ptr, doc) wraps an externalptr.
#
# Lifetime: the C-side externalptr carries a finalizer that calls
# FPDFFont_Close. The `prot` slot pins the parent doc so the doc can't
# be GC'd before the font. Calling pdf_font_close() is idempotent.
#
# To draw with a custom font, pass the `pdfium_font` handle as the
# `font` argument of pdf_text_new(); R-side dispatch picks the
# custom-font code path automatically.

# The 14 standard PDF Type 1 fonts that every PDF reader is required
# to support. PDFium accepts any of these names without needing font
# bytes to be embedded.
.pdfium_standard_fonts <- c(
  "Helvetica",
  "Helvetica-Bold",
  "Helvetica-Oblique",
  "Helvetica-BoldOblique",
  "Times-Roman",
  "Times-Bold",
  "Times-Italic",
  "Times-BoldItalic",
  "Courier",
  "Courier-Bold",
  "Courier-Oblique",
  "Courier-BoldOblique",
  "Symbol",
  "ZapfDingbats"
)

#' Load one of the 14 PDF standard fonts
#'
#' Wraps `FPDFText_LoadStandardFont`. The 14 standard fonts
#' (Helvetica / Times-Roman / Courier in their four weight+style
#' variants, plus Symbol and ZapfDingbats) are required by the PDF
#' spec to be supported by every reader, so no font bytes need to
#' be embedded.
#'
#' For arbitrary TrueType / Type1 fonts, use [pdf_font_load()].
#'
#' @param doc A `pdfium_doc` opened with `readwrite = TRUE`.
#' @param name Character scalar — one of the 14 standard font names
#'   listed in the **Standard fonts** section below.
#' @return A `pdfium_font` handle. Pass it as the `font` argument
#'   of [pdf_text_new()].
#'
#' @section Standard fonts:
#' `"Helvetica"`, `"Helvetica-Bold"`, `"Helvetica-Oblique"`,
#' `"Helvetica-BoldOblique"`, `"Times-Roman"`, `"Times-Bold"`,
#' `"Times-Italic"`, `"Times-BoldItalic"`, `"Courier"`,
#' `"Courier-Bold"`, `"Courier-Oblique"`, `"Courier-BoldOblique"`,
#' `"Symbol"`, `"ZapfDingbats"`.
#'
#' @seealso [pdf_font_load()], [pdf_text_new()], [pdf_font_close()].
#' @examples
#' \dontrun{
#' doc <- pdf_doc_new()
#' page <- pdf_page_new(doc, width = 612, height = 792)
#' font <- pdf_font_load_standard(doc, "Times-Italic")
#' pdf_text_new(page, "hello", font = font, font_size = 24,
#'              x = 72, y = 720)
#' pdf_save(doc, tempfile(fileext = ".pdf"))
#' }
#' @export
pdf_font_load_standard <- function(doc, name) {
  assert_readwrite(doc)
  checkmate::assert_choice(name, .pdfium_standard_fonts)
  ptr <- cpp_font_load_standard(doc$ptr, name)
  new_pdfium_font(ptr, doc, name)
}

#' Load a TrueType or Type1 font from bytes
#'
#' Wraps `FPDFText_LoadFont`. The font bytes are embedded into the
#' PDF up front (PDFium copies them; the input is free to be
#' garbage-collected after the call returns). Use [pdf_font_load_standard()]
#' for the 14 PDF standard fonts where no embedding is needed.
#'
#' @param doc A `pdfium_doc` opened with `readwrite = TRUE`.
#' @param font_data Either a raw vector containing the font bytes
#'   or a character path to a font file on disk.
#' @param type Character — `"truetype"` (default) for TrueType / OTF
#'   fonts, or `"type1"` for Type1 fonts.
#' @param cid Logical. If `TRUE` (the default), the font is loaded as
#'   a CID (composite) font. CID encoding is required for fonts with
#'   more than 255 glyphs — i.e. anything that needs to render
#'   non-Latin-1 text. The non-CID path (`cid = FALSE`) is smaller on
#'   disk but limited to the standard PDF encodings. When in doubt,
#'   leave this as `TRUE`.
#' @return A `pdfium_font` handle. Pass it as the `font` argument
#'   of [pdf_text_new()].
#'
#' @seealso [pdf_font_load_standard()], [pdf_text_new()],
#'   [pdf_font_close()].
#' @examples
#' \dontrun{
#' doc <- pdf_doc_new()
#' page <- pdf_page_new(doc, width = 612, height = 792)
#' ttf <- "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
#' if (file.exists(ttf)) {
#'   font <- pdf_font_load(doc, ttf)
#'   pdf_text_new(page, "hello", font = font, font_size = 24,
#'                x = 72, y = 720)
#' }
#' pdf_save(doc, tempfile(fileext = ".pdf"))
#' }
#' @export
pdf_font_load <- function(doc, font_data,
                          type = c("truetype", "type1"),
                          cid = TRUE) {
  assert_readwrite(doc)
  type <- match.arg(type)
  checkmate::assert_flag(cid)
  bytes <- coerce_font_bytes(font_data)
  type_code <- if (identical(type, "type1")) 1L else 2L
  ptr <- cpp_font_load_truetype(doc$ptr, bytes, type_code, cid)
  display <- if (is.character(font_data)) basename(font_data) else "<raw>"
  new_pdfium_font(ptr, doc, display)
}

#' Close a font handle
#'
#' Releases the underlying PDFium font. Idempotent — a second call is
#' a no-op. The finalizer attached to the externalptr also runs this
#' when R garbage-collects the `pdfium_font`, but explicit close is
#' useful when many large fonts have been loaded and you want
#' deterministic release.
#'
#' Closing a font does **not** invalidate text objects that already
#' used it — PDFium keeps an internal reference. Only the embedder's
#' R-side handle is released.
#'
#' @param font A `pdfium_font` from [pdf_font_load_standard()] or
#'   [pdf_font_load()].
#' @return Invisibly returns `font`.
#' @export
pdf_font_close <- function(font) {
  checkmate::assert_class(font, "pdfium_font")
  cpp_font_close(font$ptr)
  invisible(font)
}

# Internal: coerce the `font_data` argument (raw vector or path) into
# a raw vector ready to hand to the C++ shim. Mirrors
# coerce_jpeg_bytes() in R/image_authoring.R.
coerce_font_bytes <- function(font_data) {
  if (is.raw(font_data)) {
    checkmate::assert_raw(font_data, min.len = 1L)
    return(font_data)
  }
  if (is.character(font_data)) {
    checkmate::assert_string(font_data, min.chars = 1L)
    if (!file.exists(font_data)) {
      stop("Font file not found: ", font_data, call. = FALSE)
    }
    n <- file.info(font_data)$size
    return(readBin(font_data, what = "raw", n = n))
  }
  stop("`font_data` must be a raw vector of font bytes or a path to ",
       "a font file. Got: ", class(font_data)[[1L]], call. = FALSE)
}
