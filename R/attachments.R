# File-attachment accessors. PDFs can carry embedded files (the
# /EmbeddedFile object stream) - things like supplementary
# spreadsheets, signed-tax-return source data, ZUGFeRD XML
# invoices riding alongside the rendered invoice PDF. PDFium
# exposes them via FPDFDoc_GetAttachment*; this module surfaces
# the read side of that API.

# Internal: accept either an open pdfium_doc or a character path,
# return a (doc, on_exit) pair where on_exit is a closure the
# caller invokes when finished. Defined locally here; the rebase
# against phase-6-tier2-cleanup will delete this copy in favour of
# the canonical helper that ships in that branch's R doc helpers.
as_doc_handle <- function(x, arg = "doc") {
  if (is.character(x)) {
    doc <- pdf_open(x)
    return(list(doc = doc, on_exit = function() pdf_close(doc)))
  }
  if (!inherits(x, "pdfium_doc")) {
    stop(sprintf("`%s` must be a `pdfium_doc` or a path to a PDF file.",
                 arg), call. = FALSE)
  }
  if (!is_open(x)) {
    stop("Document has been closed.", call. = FALSE)
  }
  list(doc = x, on_exit = function() invisible(NULL))
}

#' List the files attached to a PDF document
#'
#' Returns a tibble row per `/EmbeddedFile` object in the
#' document. Wraps `FPDFDoc_GetAttachmentCount`,
#' `FPDFDoc_GetAttachment`, `FPDFAttachment_GetName`,
#' `FPDFAttachment_GetSubtype`, and `FPDFAttachment_GetFile`'s
#' size-query form.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @return A tibble with columns:
#'   * `attachment_index` integer - 1-based index into the
#'     document's attachment table; pass this to
#'     [pdf_attachment_data()] to read the file's bytes.
#'   * `name` character - filename declared in the attachment's
#'     `/F` (preferred) or `/UF` entry.
#'   * `mime_type` character - the attachment's `/Subtype`
#'     (e.g. `"application/xml"`, `"image/png"`). Empty string if
#'     none declared.
#'   * `size_bytes` numeric - the embedded file's decompressed
#'     byte size. `NA` when PDFium reports the contents are
#'     unreadable.
#'
#' Returns a 0-row tibble of the same schema when the document
#' has no attachments.
#'
#' @seealso [pdf_attachment_data()].
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) pdf_attachments(fixture)
#' @export
pdf_attachments <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  raw <- cpp_attachments_list(h$doc$ptr)
  tibble::tibble(
    attachment_index = seq_along(raw$name),
    name             = raw$name,
    mime_type        = raw$mime_type,
    size_bytes       = raw$size_bytes
  )
}

#' Read the raw bytes of an embedded file attachment
#'
#' Returns the decompressed file contents of the attachment at
#' `attachment_index` (1-based, as listed by [pdf_attachments()]).
#' Wraps `FPDFAttachment_GetFile`.
#'
#' Use the returned raw vector directly with
#' [writeBin()] to save the embedded file to disk without
#' re-encoding, or pass it to a downstream parser
#' (e.g. `xml2::read_xml(rawToChar(bytes))` for XML attachments).
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param attachment_index One-based index of the attachment in
#'   the document's attachment table.
#' @return A raw vector of file bytes.
#' @seealso [pdf_attachments()].
#' @export
pdf_attachment_data <- function(doc, attachment_index = 1L) {
  if (!is.numeric(attachment_index) || length(attachment_index) != 1L ||
        is.na(attachment_index) ||
        attachment_index != as.integer(attachment_index) ||
        attachment_index < 1L) {
    stop("`attachment_index` must be a single positive integer (1-based).",
         call. = FALSE)
  }
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  cpp_attachment_data(h$doc$ptr, as.integer(attachment_index) - 1L)
}
