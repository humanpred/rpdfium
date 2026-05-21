# Image-object creation for the page-authoring API.
#
# Wraps PDFium's `FPDFImageObj_LoadJpegFileInline` path so users can
# add JPEG content to programmatic PDFs. Sibling of pdf_path_new(),
# pdf_rect_new(), pdf_text_new() in R/obj_creators.R.
#
# JPEG-only by design for v0.1.0. Other formats (PNG, TIFF, raw
# bitmaps) need an FPDF_BITMAP wrapper class which is a separate
# design exercise — see dev/v0.2.0-plan.md.

#' Create a new image page-object from JPEG bytes
#'
#' Wraps `FPDFPageObj_NewImageObj` + `FPDFImageObj_LoadJpegFileInline`
#' to embed a JPEG into a page. The JPEG bytes are copied into the
#' PDF at the moment of creation (the "Inline" variant of PDFium's
#' loader), so the input is free to be garbage-collected immediately
#' after the call returns.
#'
#' The new image is placed at the origin (0, 0) at its natural
#' pixel size in PDF user-space points (one unit per pixel). For a
#' specific position and size, pass `bounds = c(left, bottom,
#' right, top)`; the wrapper computes the transformation matrix
#' that scales + translates the image into that rectangle.
#'
#' @param page A `pdfium_page` from [pdf_page_load()] (or a
#'   `pdfium_doc` with `page_num`). Parent doc must be readwrite.
#' @param jpeg Either a raw vector containing JPEG-encoded bytes or
#'   a character path to a JPEG file on disk. PNG / TIFF / other
#'   formats are not supported in v0.1.0; convert to JPEG with an
#'   external tool (`magick::image_write(..., format = "jpeg")` is
#'   the easy path) if needed.
#' @param bounds Optional length-4 numeric `c(left, bottom, right,
#'   top)` in PDF user-space points. When `NULL` (default), the
#'   image is placed at the origin at its natural pixel size in
#'   points (rarely what you want — pass an explicit `bounds`).
#' @return A `pdfium_obj` handle of `type = "image"`.
#' @seealso [pdf_path_new()], [pdf_rect_new()], [pdf_text_new()]
#'   for sibling creators; [pdf_image_info()],
#'   [pdf_image_bitmap()] for the read side.
#' @examples
#' \dontrun{
#' doc <- pdf_doc_new()
#' page <- pdf_page_new(doc, width = 612, height = 792)
#' jpeg_path <- system.file("img", "Rlogo.jpg", package = "jpeg")
#' if (nzchar(jpeg_path)) {
#'   pdf_image_new(page, jpeg_path,
#'                 bounds = c(72, 600, 272, 700))
#' }
#' pdf_save(doc, tempfile(fileext = ".pdf"))
#' }
#' @export
pdf_image_new <- function(page, jpeg, bounds = NULL) {
  ph <- as_page_and_doc(page)
  assert_readwrite(ph$doc)
  bytes <- coerce_jpeg_bytes(jpeg)
  if (!is.null(bounds)) {
    checkmate::assert_numeric(
      bounds, len = 4L, any.missing = FALSE, finite = TRUE
    )
  }
  ptr <- cpp_image_new_from_jpeg(ph$doc$ptr, ph$page$ptr, bytes)
  if (!is.null(bounds)) {
    width <- bounds[[3L]] - bounds[[1L]]
    height <- bounds[[4L]] - bounds[[2L]]
    # PDFium's image unit-square gets mapped by this matrix: scale to
    # (width, height) and translate by (left, bottom). The PDF spec
    # convention is that an image object's natural coordinate space
    # is [0, 1] × [0, 1] before its CTM applies.
    ok <- cpp_image_set_matrix(
      ptr, width, 0, 0, height, bounds[[1L]], bounds[[2L]]
    )
    if (!isTRUE(ok)) {
      stop("FPDFImageObj_SetMatrix failed.", call. = FALSE)  # nocov
    }
  }
  idx <- cpp_page_object_count(ph$page$ptr)
  mark_page_dirty(ph$doc, ph$page$index)
  new_pdfium_obj(ptr, ph$page, idx, "image")
}

# Internal: coerce the `jpeg` argument (raw vector or path) into
# a raw vector of JPEG bytes ready to hand to the C++ shim.
coerce_jpeg_bytes <- function(jpeg) {
  if (is.raw(jpeg)) {
    checkmate::assert_raw(jpeg, min.len = 1L)
    return(jpeg)
  }
  if (is.character(jpeg)) {
    checkmate::assert_string(jpeg, min.chars = 1L)
    if (!file.exists(jpeg)) {
      stop("JPEG file not found: ", jpeg, call. = FALSE)
    }
    n <- file.info(jpeg)$size
    return(readBin(jpeg, what = "raw", n = n))
  }
  stop("`jpeg` must be a raw vector of JPEG bytes or a path to a ",
       "JPEG file. Got: ", class(jpeg)[[1L]], call. = FALSE)
}
