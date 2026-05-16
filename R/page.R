#' Load a single page from an open PDF document
#'
#' Returns a `pdfium_page` handle bound to its parent `doc`. The page is
#' garbage-collected with a finalizer that calls `FPDF_ClosePage`; call
#' [pdf_close_page()] explicitly when you need deterministic release.
#' The page keeps the parent document alive for as long as the page
#' is reachable, so it is safe to drop your reference to `doc` while
#' still holding a page.
#'
#' @param doc A `pdfium_doc` from [pdf_open()].
#' @param page_num One-based page index. Must satisfy
#'   `1 <= page_num <= pdf_page_count(doc)`.
#' @return A `pdfium_page` object.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   page <- pdf_load_page(doc, 1)
#'   pdf_close_page(page)
#'   pdf_close(doc)
#' }
#' @export
pdf_load_page <- function(doc, page_num = 1L) {
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` (from `pdf_open()`).", call. = FALSE)
  }
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  if (!is.numeric(page_num) || length(page_num) != 1L || is.na(page_num) ||
        page_num != as.integer(page_num) || page_num < 1L) {
    stop("`page_num` must be a single positive integer (1-based).",
         call. = FALSE)
  }
  page_num <- as.integer(page_num)
  n <- cpp_page_count(doc$ptr)
  if (page_num > n) {
    stop(sprintf("`page_num` (%d) exceeds the document's page count (%d).",
                 page_num, n), call. = FALSE)
  }
  ptr <- cpp_load_page(doc$ptr, page_num - 1L)
  new_pdfium_page(ptr, doc, page_num)
}

#' Close a page handle
#'
#' Releases the underlying PDFium handle. Idempotent — calling
#' `pdf_close_page()` on an already-closed page is a no-op.
#'
#' @param page A `pdfium_page` from [pdf_load_page()].
#' @return Invisibly returns `page` with its underlying pointer marked closed.
#' @export
pdf_close_page <- function(page) {
  if (!inherits(page, "pdfium_page")) {
    stop("`page` must be a `pdfium_page` (from `pdf_load_page()`).",
         call. = FALSE)
  }
  cpp_close_page(page$ptr)
  invisible(page)
}

#' Page dimensions in PDF points
#'
#' Returns the width and height of `page` in PDF points (1 point = 1/72 inch).
#' Accepts either a `pdfium_page` (preferred when you already have one) or
#' a `(doc, page)` pair (convenience for one-shot inspection).
#'
#' The returned dimensions are **media-box** dimensions in the page's
#' default (un-rotated) orientation. If the page has a non-zero
#' rotation (via the PDF `/Rotate` attribute or PDFium's runtime
#' rotation), `pdf_page_size()` does not swap width and height. Query
#' the rotation separately with [pdf_page_rotation()] if you need to
#' know the on-screen orientation.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A named numeric vector with elements `width` and
#'   `height`.
#'
#' @seealso [pdf_page_rotation()] for the rotation angle in degrees.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   pdf_page_size(doc, 1)
#'   pdf_close(doc)
#' }
#' @export
pdf_page_size <- function(page, page_num = 1L) {
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) stop("Page has been closed.", call. = FALSE)
    return(cpp_page_size(page$ptr))
  }
  if (inherits(page, "pdfium_doc")) {
    p <- pdf_load_page(page, page_num)
    on.exit(pdf_close_page(p), add = TRUE)
    return(cpp_page_size(p$ptr))
  }
  stop("`page` must be a `pdfium_page` or `pdfium_doc`.", call. = FALSE)
}

#' Page rotation in degrees
#'
#' Returns the page's rotation as `0`, `90`, `180`, or `270` degrees.
#' PDFium reports the rotation stored in the page's `/Rotate` entry
#' combined with any runtime rotation applied via the editing API.
#'
#' A non-zero rotation means [pdf_page_size()]'s `width` and `height`
#' refer to the page's pre-rotation media box, not the on-screen
#' dimensions a viewer would display. For an "as-displayed" size, swap
#' `width` and `height` when rotation is `90` or `270`.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return An integer in `{0, 90, 180, 270}`.
#'
#' @seealso [pdf_page_size()] for the un-rotated dimensions.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   pdf_page_rotation(doc, 1)
#'   pdf_close(doc)
#' }
#' @export
pdf_page_rotation <- function(page, page_num = 1L) {
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) stop("Page has been closed.", call. = FALSE)
    return(cpp_page_rotation(page$ptr))
  }
  if (inherits(page, "pdfium_doc")) {
    p <- pdf_load_page(page, page_num)
    on.exit(pdf_close_page(p), add = TRUE)
    return(cpp_page_rotation(p$ptr))
  }
  stop("`page` must be a `pdfium_page` or `pdfium_doc`.", call. = FALSE)
}
