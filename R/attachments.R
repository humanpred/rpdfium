# File-attachment accessors. PDFs can carry embedded files (the
# /EmbeddedFile object stream) - things like supplementary
# spreadsheets, signed-tax-return source data, ZUGFeRD XML
# invoices riding alongside the rendered invoice PDF. PDFium
# exposes them via FPDFDoc_GetAttachment*; this module surfaces
# the read side of that API.

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
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_attachments(fixture)
#' @export
pdf_attachments <- function(doc) {
  doc <- as_open_doc(doc)
  raw <- cpp_attachments_list(doc$ptr)
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
  checkmate::assert_count(attachment_index, positive = TRUE)
  doc <- as_open_doc(doc)
  cpp_attachment_data(doc$ptr, as.integer(attachment_index) - 1L)
}
