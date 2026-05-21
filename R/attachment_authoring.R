# Attachment authoring (Phase 8 of the v0.1.0 writer surface).
#
# Four exports plus a per-doc helper:
#
#   pdf_attachment_new(doc, name)              create + return handle
#   pdf_attachment_delete(att)                 remove by index
#   pdf_attachment_set_dict_value(att, k, v)   set /Params entry
#   pdf_attachment_set_data(att, data)         set the embedded file
#                                                bytes
#
# All require `doc` (or `att$doc`) to be readwrite. Attachments are
# doc-owned — they have no per-page index — so the setters skip the
# dirty-page bookkeeping; `pdf_save()` always serialises the whole
# document and picks them up automatically.

# Internal: validate that `att` is an open pdfium_attachment whose
# parent doc is readwrite.
assert_attachment_writable <- function(att, arg = "att") {
  check_attachment(att, arg = arg)
  assert_readwrite(att$doc)
  invisible(att)
}

#' Add a new embedded file attachment to a document
#'
#' Creates a new `/EmbeddedFile` entry in `doc`'s name tree, with the
#' given filename. The returned handle is a `pdfium_attachment` that
#' you can pass to [pdf_attachment_set_data()] to populate the file
#' bytes, and [pdf_attachment_set_dict_value()] to populate dictionary
#' metadata (`"Subtype"`, `"Desc"`, etc.).
#'
#' Wraps `FPDFDoc_AddAttachment`. The new attachment is appended to
#' the end of the document's existing attachment list, and its
#' `$index` field reflects the resulting 1-based index. PDFium will
#' refuse the creation (returning `NULL`, which we surface as an R
#' error) if:
#'
#' * `name` is empty;
#' * `name` is the name of an existing embedded file in `doc`;
#' * the document's name tree is at its depth limit.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()] or
#'   [pdf_doc_new()]. Must be readwrite.
#' @param name Character scalar — the attachment's filename. UTF-8
#'   accepted.
#' @return A `pdfium_attachment` handle. The attachment is empty —
#'   call [pdf_attachment_set_data()] to populate its contents.
#' @seealso [pdf_attachments()] for the read side,
#'   [pdf_attachment_delete()] to remove an attachment.
#' @export
pdf_attachment_new <- function(doc, name) {
  checkmate::assert_class(doc, "pdfium_doc")
  assert_readwrite(doc)
  checkmate::assert_string(name, min.chars = 1L, na.ok = FALSE)
  ptr <- cpp_attachment_new(doc$ptr, enc2utf8(name))
  # New attachment is appended; its 1-based index is the count
  # post-add.
  idx <- cpp_attachment_count(doc$ptr)
  new_pdfium_attachment(ptr, doc, idx)
}

#' Delete an embedded file attachment from a document
#'
#' Removes the attachment's entry from the document's `/EmbeddedFiles`
#' name tree. Wraps `FPDFDoc_DeleteAttachment`. The handle becomes
#' closed (subsequent reads / writes through it error cleanly);
#' indexes of any later attachments shift down by one in PDFium's
#' internal list — re-fetch via [pdf_attachments()] if you held
#' other handles past this point.
#'
#' Note: PDFium's delete only removes the name-tree pointer; the
#' underlying `/EmbeddedFile` object may still occupy bytes in the
#' saved PDF. This matches `FPDFDoc_DeleteAttachment`'s documented
#' behaviour.
#'
#' @param att A `pdfium_attachment` from [pdf_attachments()] or
#'   [pdf_attachment_new()]. Parent doc must be readwrite.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_attachment_new()].
#' @export
pdf_attachment_delete <- function(att) {
  assert_attachment_writable(att)
  doc <- att$doc
  ok <- cpp_attachment_delete(doc$ptr, att$index - 1L)
  if (!ok) {
    stop("FPDFDoc_DeleteAttachment failed.", call. = FALSE)  # nocov
  }
  # Null the externalptr so subsequent reads / writes via this
  # handle error cleanly. PDFium has freed the underlying
  # FPDF_ATTACHMENT.
  cpp_attachment_clear_ptr(att$ptr)
  invisible(doc)
}

#' Set an entry in an attachment's `/Params` dictionary
#'
#' Writes a string-valued entry in the attachment's parameter
#' dictionary. Common keys:
#'
#' * `"Desc"` — a human-readable description.
#' * `"AFRelationship"` — the AF/EF relationship type
#'   (`"Source"`, `"Data"`, `"Alternative"`, etc.).
#' * `"ModDate"` — modification date as a PDF date string (see
#'   [pdf_parse_date()] for the format).
#'
#' Wraps `FPDFAttachment_SetStringValue`, which writes into the
#' attachment's `/Params` subdictionary. Mirrors
#' [pdf_attachment_dict_value()] on the read side.
#'
#' **Ordering**: PDFium's `FPDFAttachment_SetStringValue` requires the
#' attachment's `/Params` dictionary to already exist. Call
#' [pdf_attachment_set_data()] first on any attachment that doesn't
#' have one yet (the file data write auto-creates `/Params`,
#' populating `Size`, `CreationDate`, and `CheckSum`); only then can
#' you append further keys with this function. On a fresh attachment
#' from [pdf_attachment_new()] this means the natural sequence is
#' `pdf_attachment_new()` → `pdf_attachment_set_data()` →
#' `pdf_attachment_set_dict_value()`.
#'
#' **Not exposed**: the file stream's own `/Subtype` entry (the MIME
#' type returned by [pdf_attachment_mime_type()]) lives on the
#' attachment's embedded file stream, not on `/Params`, and PDFium
#' has no public setter for it. Passing `key = "Subtype"` here writes
#' `/Params/Subtype`, which won't be picked up by
#' [pdf_attachment_mime_type()]. See `dev/upstream-patches/` for the
#' upstream gap.
#'
#' **Encoding**: PDFium's `FPDFAttachment_SetStringValue` stores the
#' value as a PDF byte-string interpreted in PDFDocEncoding on read.
#' ASCII round-trips cleanly; non-ASCII Unicode characters are
#' lossy through the read path (the bytes are written but
#' `FPDFAttachment_GetStringValue`'s `GetUnicodeText` step
#' misinterprets multi-byte UTF-8 sequences as PDFDocEncoding bytes).
#' This is a PDFium-side inconsistency — `FPDFAnnot_SetStringValue`
#' uses the wide-string-aware CPDF_String path and round-trips
#' Unicode correctly. Until upstream is fixed, restrict
#' attachment-dict values to ASCII when round-trip fidelity matters.
#'
#' @inheritParams pdf_attachment_delete
#' @param key The dictionary key as a non-empty character scalar.
#' @param value The string value as a character scalar; UTF-8
#'   accepted.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_attachment_dict_value()].
#' @export
pdf_attachment_set_dict_value <- function(att, key, value) {
  assert_attachment_writable(att)
  key <- assert_pdf_key(key)
  checkmate::assert_string(value, na.ok = FALSE)
  ok <- cpp_attachment_set_dict_value(att$ptr, key, enc2utf8(value))
  if (!ok) {
    stop("FPDFAttachment_SetStringValue failed.", call. = FALSE)  # nocov
  }
  invisible(att$doc)
}

#' Set the raw bytes of an embedded file attachment
#'
#' Replaces the attachment's embedded file data with the given raw
#' bytes. Wraps `FPDFAttachment_SetFile`. The attachment's
#' `CreationDate` and checksum dictionary entries are automatically
#' updated; **all other entries** (including the MIME `Subtype` and
#' the `Desc` you may have set with
#' [pdf_attachment_set_dict_value()]) are cleared by PDFium during
#' the write — set those entries _after_ this call.
#'
#' Use this immediately after [pdf_attachment_new()] to populate a
#' fresh attachment, or to update the file contents of an existing
#' one.
#'
#' @inheritParams pdf_attachment_delete
#' @param data A raw vector of file bytes. To attach a UTF-8 text
#'   payload, pass `charToRaw(enc2utf8(text))`.
#' @return Invisibly returns the parent `pdfium_doc`.
#' @seealso [pdf_attachment_data()] for the read side.
#' @export
pdf_attachment_set_data <- function(att, data) {
  assert_attachment_writable(att)
  checkmate::assert_raw(data)
  ok <- cpp_attachment_set_data(att$ptr, att$doc$ptr, data)
  if (!ok) {
    stop("FPDFAttachment_SetFile failed.", call. = FALSE)  # nocov
  }
  invisible(att$doc)
}
