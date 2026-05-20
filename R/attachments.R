# File-attachment accessors. PDFs can carry embedded files (the
# /EmbeddedFile object stream) - things like supplementary
# spreadsheets, signed-tax-return source data, ZUGFeRD XML
# invoices riding alongside the rendered invoice PDF. PDFium
# exposes them via FPDFDoc_GetAttachment*; this module surfaces
# the read side of that API as a list-of-handles per ADR-017.

#' List the files attached to a PDF document
#'
#' Returns a `pdfium_attachment_list` — a list of
#' `pdfium_attachment` handles, one per `/EmbeddedFile` in the
#' document. Each handle is a thin wrapper around an
#' `FPDF_ATTACHMENT` owned by the parent doc; the per-attribute
#' getters ([pdf_attachment_name()], [pdf_attachment_mime_type()],
#' [pdf_attachment_size_bytes()], [pdf_attachment_data()],
#' [pdf_attachment_dict_value()]) operate on a single handle.
#'
#' Use `tibble::as_tibble(pdf_attachments(doc))` for the tibble
#' view; the resulting tibble carries `handle` and `source`
#' list-columns that survive round-trip through
#' [as_pdfium_attachment_list()].
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character
#'   path.
#' @return A `pdfium_attachment_list` (empty if the document has
#'   no attachments).
#' @seealso [pdf_attachment_data()], [pdf_attachment_dict_value()].
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_attachments(fixture)
#' @export
pdf_attachments <- function(doc) {
  # Don't defer-close the transient doc — the returned handles
  # pin it via their externalptr `prot` slots.
  doc <- as_open_doc(doc, defer_close = FALSE)
  n <- cpp_attachment_count(doc$ptr)
  handles <- lapply(seq_len(n), function(i) {
    ptr <- cpp_attachment_get(doc$ptr, as.integer(i - 1L))
    new_pdfium_attachment(ptr, doc, i)
  })
  new_pdfium_attachment_list(handles, doc)
}

#' Tibble view of a `pdfium_attachment_list`
#'
#' Walks every attachment in the list and reads its
#' name / mime-type / size-bytes into a tibble. Adds `handle` and
#' `source` list-columns (ADR-017).
#'
#' Internally calls the existing bulk reader (`cpp_attachments_list`)
#' for speed.
#'
#' @param x A `pdfium_attachment_list` from [pdf_attachments()].
#' @param ... Unused (S3 generic compatibility).
#' @return A tibble with columns `attachment_index`, `name`,
#'   `mime_type`, `size_bytes`, `handle`, `source`.
#' @importFrom tibble as_tibble
#' @method as_tibble pdfium_attachment_list
#' @export
as_tibble.pdfium_attachment_list <- function(x, ...) {
  src_doc <- attr(x, "source")
  if (length(x) == 0L) {
    return(empty_attachment_tibble())
  }
  raw <- cpp_attachments_list(src_doc$ptr)
  tibble::tibble(
    attachment_index = seq_along(raw$name),
    name             = raw$name,
    mime_type        = raw$mime_type,
    size_bytes       = raw$size_bytes,
    handle           = unclass(x),
    source           = rep(list(src_doc), length(x))
  )
}

# Internal: zero-row tibble matching as_tibble.pdfium_attachment_list.
empty_attachment_tibble <- function() {
  tibble::tibble(
    attachment_index = integer(),
    name             = character(),
    mime_type        = character(),
    size_bytes       = numeric(),
    handle           = list(),
    source           = list()
  )
}

#' Coerce input to a `pdfium_attachment_list`
#'
#' Reverse companion to [as_tibble.pdfium_attachment_list()].
#'
#' @param x Either a `pdfium_attachment_list`, a plain list of
#'   `pdfium_attachment` handles, or a tibble with a `handle`
#'   list-column.
#' @return A `pdfium_attachment_list`.
#' @export
as_pdfium_attachment_list <- function(x) {
  if (inherits(x, "pdfium_attachment_list")) return(x)
  if (is.list(x) && length(x) > 0L &&
      all(vapply(x, inherits, logical(1L), "pdfium_attachment"))) {
    src_doc <- x[[1L]]$doc
    return(new_pdfium_attachment_list(x, src_doc))
  }
  if (tibble::is_tibble(x) && "handle" %in% names(x)) {
    handles <- x$handle
    if (length(handles) == 0L) {
      stop("Cannot rebuild a `pdfium_attachment_list` from a zero-",
           "row tibble (source doc unknown).", call. = FALSE)
    }
    src_doc <- x$source[[1L]]
    return(new_pdfium_attachment_list(handles, src_doc))
  }
  stop("`x` must be a `pdfium_attachment_list`, a list of ",
       "`pdfium_attachment`, or a tibble produced by ",
       "`as_tibble(pdf_attachments(doc))`.", call. = FALSE)
}

# Internal validator
check_attachment <- function(att, arg = "att") {
  checkmate::assert_class(att, "pdfium_attachment", .var.name = arg)
  if (!is_open(att)) {
    stop("Attachment handle has been closed.", call. = FALSE)
  }
  invisible(att)
}

#' Attachment file name
#'
#' Returns the filename declared in the attachment's `/F`
#' (preferred) or `/UF` entry. Wraps `FPDFAttachment_GetName`.
#'
#' @param att A `pdfium_attachment` handle from
#'   [pdf_attachments()].
#' @return Character scalar (UTF-8). Empty string if no name.
#' @export
pdf_attachment_name <- function(att) {
  check_attachment(att)
  cpp_attachment_name(att$ptr)
}

#' Attachment MIME / subtype
#'
#' Returns the attachment's declared `/Subtype` (typically a MIME
#' type such as `"application/xml"`). Wraps
#' `FPDFAttachment_GetSubtype`.
#'
#' @inheritParams pdf_attachment_name
#' @return Character scalar; empty if no subtype declared.
#' @export
pdf_attachment_mime_type <- function(att) {
  check_attachment(att)
  cpp_attachment_subtype(att$ptr)
}

#' Attachment decompressed size in bytes
#'
#' Returns the embedded file's decompressed byte size, or `NA`
#' when PDFium reports the contents are unreadable.
#'
#' @inheritParams pdf_attachment_name
#' @return Numeric scalar.
#' @export
pdf_attachment_size_bytes <- function(att) {
  check_attachment(att)
  cpp_attachment_size_bytes(att$ptr)
}

#' Read the raw bytes of an embedded file attachment
#'
#' Returns the decompressed file contents of the attachment.
#' Wraps `FPDFAttachment_GetFile`.
#'
#' Use the returned raw vector directly with [writeBin()] to save
#' the embedded file to disk without re-encoding, or pass it to a
#' downstream parser (e.g. `xml2::read_xml(rawToChar(bytes))` for
#' XML attachments).
#'
#' @inheritParams pdf_attachment_name
#' @return A raw vector of file bytes.
#' @seealso [pdf_attachments()].
#' @export
pdf_attachment_data <- function(att) {
  check_attachment(att)
  cpp_attachment_data_handle(att$ptr)
}

#' Look up an attachment-dictionary entry by key
#'
#' PDF attachments carry a `/Params` dictionary with metadata about
#' the embedded file (size, modification date, checksums, MIME
#' type, custom keys). [pdf_attachments()] surfaces the common
#' entries; this function reads an arbitrary key. Wraps
#' `FPDFAttachment_HasKey` + `FPDFAttachment_GetValueType` +
#' `FPDFAttachment_GetStringValue`.
#'
#' Only string- and name-typed values are returned as character
#' scalars. For numeric / boolean / dict values the function
#' reports `has_key = TRUE` and `value_type` accordingly but
#' `value = NA_character_` (use [pdf_attachments()] for the
#' structured size/date/checksum readouts).
#'
#' @inheritParams pdf_attachment_name
#' @param key The attachment-dict key as a single non-empty
#'   character string (e.g. `"Subtype"`, `"AFRelationship"`).
#' @return A list:
#'   * `has_key` (logical) — `TRUE` when the attachment dict
#'     contains the key.
#'   * `value_type` (integer) — PDFium's `FPDF_OBJECT_*` enum
#'     value; `NA` when the key is absent.
#'   * `value` (character) — the string / name value;
#'     `NA_character_` when the value is not string-typed.
#' @seealso [pdf_attachments()].
#' @export
pdf_attachment_dict_value <- function(att, key) {
  check_attachment(att)
  key <- assert_pdf_key(key)
  raw <- cpp_attachment_dict_value_handle(att$ptr, key)
  val_chr <- as.character(raw$value)
  # nocov start — defensive: cpp always returns a length-1 chr.
  if (length(val_chr) == 0L) val_chr <- NA_character_
  # nocov end
  list(
    has_key    = as.logical(raw$has_key),
    value_type = as.integer(raw$value_type),
    value      = val_chr[[1L]]
  )
}
