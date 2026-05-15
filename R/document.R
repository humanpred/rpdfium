#' Open a PDF document
#'
#' Loads a PDF file from disk. The returned `pdfium_doc` carries an external
#' pointer to a PDFium `FPDF_DOCUMENT` handle along with a finalizer that
#' calls `FPDF_CloseDocument()` when the R object is garbage-collected. Call
#' [pdf_close()] explicitly when you need deterministic release.
#'
#' @param path Character scalar. Path to a PDF file. The file must exist and be
#'   readable.
#' @param password Optional password for encrypted PDFs. `NULL` (the default)
#'   passes no password to PDFium, which works for both unencrypted documents
#'   and the rare case of empty-string-password encryption. Provide a string
#'   when the document requires it. Future minor releases will broaden support
#'   for password-protected PDFs; the parameter is present in v0.1.0 to
#'   reserve the signature.
#' @return A `pdfium_doc` object.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   pdf_page_count(doc)
#'   pdf_close(doc)
#' }
#' @export
pdf_open <- function(path, password = NULL) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    stop("`path` must be a single, non-NA character string.", call. = FALSE)
  }
  if (!nzchar(path)) {
    stop("`path` must not be the empty string.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("PDF file not found: ", path, call. = FALSE)
  }
  if (!is.null(password) &&
      (!is.character(password) || length(password) != 1L || is.na(password))) {
    stop("`password` must be NULL or a single non-NA character string.",
         call. = FALSE)
  }
  ptr <- cpp_open_document(path.expand(path),
                           if (is.null(password)) "" else password)
  new_pdfium_doc(ptr, normalizePath(path, winslash = "/", mustWork = FALSE))
}

#' Close a PDF document
#'
#' Releases the underlying PDFium handle. Idempotent — calling `pdf_close()` on
#' an already-closed document is a no-op. The finalizer registered at
#' [pdf_open()] also calls this when the R object is garbage-collected, but
#' explicit close is recommended when handling many large documents or when a
#' subsequent operation needs to delete the source file (relevant on Windows).
#'
#' @param doc A `pdfium_doc` produced by [pdf_open()].
#' @return Invisibly returns `doc` with its underlying pointer marked closed.
#' @export
pdf_close <- function(doc) {
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` (from `pdf_open()`).", call. = FALSE)
  }
  cpp_close_document(doc$ptr)
  invisible(doc)
}

#' Count pages in a PDF document
#'
#' Returns the number of pages in `doc`. Accepts either an open `pdfium_doc`
#' or a character path (in which case it opens and closes the document
#' internally — convenient for one-shot inspection).
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character scalar path.
#' @return An integer scalar — the page count.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   pdf_page_count(fixture)
#' }
#' @export
pdf_page_count <- function(doc) {
  if (is.character(doc)) {
    handle <- pdf_open(doc)
    on.exit(pdf_close(handle), add = TRUE)
    return(cpp_page_count(handle$ptr))
  }
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` or a path to a PDF file.", call. = FALSE)
  }
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  cpp_page_count(doc$ptr)
}
