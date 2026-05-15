#' Construct a `pdfium_doc` from an external pointer
#'
#' Internal helper. Wraps the `externalptr` returned by `cpp_open_document()`
#' in the S3 class hierarchy and stores the source path for display.
#'
#' @param ptr An `externalptr` to a PDFium `FPDF_DOCUMENT` handle.
#' @param path Character scalar — the source path the document was loaded from.
#' @return An object of class `c("pdfium_doc", "pdfium_handle")`.
#' @keywords internal
#' @noRd
new_pdfium_doc <- function(ptr, path) {
  stopifnot(typeof(ptr) == "externalptr", is.character(path), length(path) == 1L)
  structure(
    list(ptr = ptr, path = path),
    class = c("pdfium_doc", "pdfium_handle")
  )
}

#' Check whether a handle is still open
#'
#' @param x A `pdfium_handle` (`pdfium_doc` or `pdfium_page`).
#' @return `TRUE` if the underlying PDFium handle is still live, `FALSE`
#'   if [pdf_close()] has been called.
#' @keywords internal
#' @noRd
is_open <- function(x) {
  stopifnot(inherits(x, "pdfium_handle"))
  cpp_handle_is_valid(x$ptr)
}

#' @export
format.pdfium_doc <- function(x, ...) {
  state <- if (is_open(x)) "open" else "closed"
  sprintf("<pdfium_doc [%s] %s>", state, x$path)
}

#' @export
print.pdfium_doc <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}
