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
#' @param page One-based page index. Must satisfy
#'   `1 <= page <= pdf_page_count(doc)`.
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
pdf_load_page <- function(doc, page = 1L) {
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` (from `pdf_open()`).", call. = FALSE)
  }
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  if (!is.numeric(page) || length(page) != 1L || is.na(page) ||
        page != as.integer(page) || page < 1L) {
    stop("`page` must be a single positive integer (1-based).", call. = FALSE)
  }
  page <- as.integer(page)
  n <- cpp_page_count(doc$ptr)
  if (page > n) {
    stop(sprintf("`page` (%d) exceeds the document's page count (%d).",
                 page, n), call. = FALSE)
  }
  ptr <- cpp_load_page(doc$ptr, page - 1L)
  new_pdfium_page(ptr, doc, page)
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
#' @param x A `pdfium_page` from [pdf_load_page()], or a `pdfium_doc`.
#' @param page One-based page index. Only used when `x` is a `pdfium_doc`.
#'   Ignored otherwise.
#' @return A named numeric vector with elements `width` and `height`.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   pdf_page_size(doc, 1)
#'   pdf_close(doc)
#' }
#' @export
pdf_page_size <- function(x, page = 1L) {
  if (inherits(x, "pdfium_page")) {
    if (!is_open(x)) stop("Page has been closed.", call. = FALSE)
    return(cpp_page_size(x$ptr))
  }
  if (inherits(x, "pdfium_doc")) {
    p <- pdf_load_page(x, page)
    on.exit(pdf_close_page(p), add = TRUE)
    return(cpp_page_size(p$ptr))
  }
  stop("`x` must be a `pdfium_page` or `pdfium_doc`.", call. = FALSE)
}
