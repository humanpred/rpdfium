# Digital-signature accessors. PDF signatures (PDF spec 12.8)
# carry one or more cryptographic signing operations over the
# document's byte stream. PDFium gives us per-signature metadata
# plus access to the signature's contents (the PKCS#7 / PKCS#1
# blob) and the signed byte range (which spans the document are
# covered by the digest).
#
# This module exposes the read side as a list-of-handles per
# ADR-017. We don't ship signature *verification* in v0.1.0 —
# that's a PKI cryptography concern (download CRLs, check
# timestamp authority, validate cert chain against trust anchors)
# that belongs in a downstream package layered on top of, e.g.,
# openssl::pkcs7_verify().

#' List the digital signatures attached to a PDF document
#'
#' Returns a `pdfium_signature_list` — a list of
#' `pdfium_signature` handles, one per signature object in the
#' document. Per-attribute getters
#' ([pdf_signature_sub_filter()], [pdf_signature_reason()],
#' [pdf_signature_time()], [pdf_signature_doc_mdp_permission()],
#' [pdf_signature_contents()], [pdf_signature_byte_range()])
#' operate on a single handle.
#'
#' Use `tibble::as_tibble(pdf_signatures(doc))` for the tibble
#' view.
#'
#' Wraps `FPDF_GetSignatureCount`, `FPDF_GetSignatureObject`, and
#' the `FPDFSignatureObj_*` family.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character
#'   path.
#' @return A `pdfium_signature_list` (empty if no signatures).
#' @seealso [pdf_signature_contents()],
#'   [pdf_signature_byte_range()], [pdf_parse_date()] for parsing
#'   the time string.
#' @export
pdf_signatures <- function(doc) {
  doc <- as_open_doc(doc, defer_close = FALSE)
  n <- cpp_signature_count(doc$ptr)
  handles <- lapply(seq_len(n), function(i) {
    ptr <- cpp_signature_get(doc$ptr, as.integer(i - 1L))
    new_pdfium_signature(ptr, doc, i)
  })
  new_pdfium_signature_list(handles, doc)
}

#' Tibble view of a `pdfium_signature_list`
#'
#' Walks every signature in the list and reads its metadata into a
#' tibble. Adds `handle` and `source` list-columns (ADR-017).
#'
#' @param x A `pdfium_signature_list` from [pdf_signatures()].
#' @param ... Unused (S3 generic compatibility).
#' @return A tibble with the previous `pdf_signatures()` columns
#'   plus `handle` and `source`.
#' @importFrom tibble as_tibble
#' @method as_tibble pdfium_signature_list
#' @export
as_tibble.pdfium_signature_list <- function(x, ...) {
  src_doc <- attr(x, "source")
  if (length(x) == 0L) {
    return(empty_signature_tibble())
  }
  raw <- cpp_signatures_list(src_doc$ptr)
  tibble::tibble(
    signature_index    = seq_along(raw$sub_filter),
    sub_filter         = raw$sub_filter,
    reason             = raw$reason,
    time               = raw$time,
    doc_mdp_permission = as.integer(raw$doc_mdp_permission),
    contents_size      = as.integer(raw$contents_size),
    byte_range_pairs   = as.integer(raw$byte_range_pairs),
    handle             = unclass(x),
    source             = rep(list(src_doc), length(x))
  )
}

empty_signature_tibble <- function() {
  tibble::tibble(
    signature_index    = integer(),
    sub_filter         = character(),
    reason             = character(),
    time               = character(),
    doc_mdp_permission = integer(),
    contents_size      = integer(),
    byte_range_pairs   = integer(),
    handle             = list(),
    source             = list()
  )
}

#' Coerce input to a `pdfium_signature_list`
#'
#' Reverse companion to [as_tibble.pdfium_signature_list()].
#'
#' @param x Either a `pdfium_signature_list`, a list of
#'   `pdfium_signature` handles, or a tibble with a `handle`
#'   list-column.
#' @return A `pdfium_signature_list`.
#' @export
as_pdfium_signature_list <- function(x) {
  if (inherits(x, "pdfium_signature_list")) return(x)
  if (is.list(x) && length(x) > 0L &&
      all(vapply(x, inherits, logical(1L), "pdfium_signature"))) {
    src_doc <- x[[1L]]$doc
    return(new_pdfium_signature_list(x, src_doc))
  }
  if (tibble::is_tibble(x) && "handle" %in% names(x)) {
    handles <- x$handle
    if (length(handles) == 0L) {
      stop("Cannot rebuild a `pdfium_signature_list` from a zero-",
           "row tibble (source doc unknown).", call. = FALSE)
    }
    src_doc <- x$source[[1L]]
    return(new_pdfium_signature_list(handles, src_doc))
  }
  stop("`x` must be a `pdfium_signature_list`, a list of ",
       "`pdfium_signature`, or a tibble produced by ",
       "`as_tibble(pdf_signatures(doc))`.", call. = FALSE)
}

# Internal validator
check_signature <- function(sig, arg = "sig") {
  checkmate::assert_class(sig, "pdfium_signature", .var.name = arg)
  if (!is_open(sig)) {
    stop("Signature handle has been closed.", call. = FALSE)
  }
  invisible(sig)
}

#' Signature `/SubFilter` value
#'
#' Returns the signature's `/SubFilter` field
#' (e.g. `"adbe.pkcs7.detached"`, `"ETSI.CAdES.detached"`,
#' `"adbe.x509.rsa_sha1"`). ASCII. Wraps
#' `FPDFSignatureObj_GetSubFilter`.
#'
#' @param sig A `pdfium_signature` handle from [pdf_signatures()].
#' @return Character scalar.
#' @export
pdf_signature_sub_filter <- function(sig) {
  check_signature(sig)
  cpp_signature_sub_filter_handle(sig$ptr)
}

#' Signature reason / comment text
#'
#' Returns the UTF-8 reason string attached when the signer wrote
#' one. Empty if absent. Wraps `FPDFSignatureObj_GetReason`.
#'
#' @inheritParams pdf_signature_sub_filter
#' @return Character scalar.
#' @export
pdf_signature_reason <- function(sig) {
  check_signature(sig)
  cpp_signature_reason_handle(sig$ptr)
}

#' Signing time (raw PDF date string)
#'
#' Returns the signing time as the raw PDF date string
#' (`"D:YYYYMMDDHHmmSS+HH'mm'"`). Empty if the signature defers to
#' the PKCS#7 timestamp. Pass to [pdf_parse_date()] for POSIXct.
#' Wraps `FPDFSignatureObj_GetTime`.
#'
#' @inheritParams pdf_signature_sub_filter
#' @return Character scalar.
#' @export
pdf_signature_time <- function(sig) {
  check_signature(sig)
  cpp_signature_time_handle(sig$ptr)
}

#' Signature DocMDP permission level
#'
#' Returns the PDF DocMDP permission level (`1`, `2`, or `3`) or
#' `NA` when no DocMDP entry is present. Wraps
#' `FPDFSignatureObj_GetDocMDPPermission`.
#'
#' Level 1 = no changes; 2 = form-fill only; 3 = form-fill +
#' annotations + signing fields.
#'
#' @inheritParams pdf_signature_sub_filter
#' @return Integer scalar (1/2/3) or `NA`.
#' @export
pdf_signature_doc_mdp_permission <- function(sig) {
  check_signature(sig)
  cpp_signature_docmdp_handle(sig$ptr)
}

#' Read the raw bytes of a PDF signature's contents blob
#'
#' Returns the DER-encoded PKCS#7 (for `adbe.pkcs7.*` /
#' `ETSI.CAdES.detached` sub-filters) or PKCS#1 (for
#' `adbe.x509.rsa_sha1`) signature blob. Feed this into a PKI
#' library to actually verify the signature (e.g.
#' `openssl::pkcs7_verify(bytes, data = signed_bytes)`).
#'
#' Wraps `FPDFSignatureObj_GetContents`.
#'
#' @inheritParams pdf_signature_sub_filter
#' @return A raw vector of the signature blob.
#' @seealso [pdf_signature_byte_range()].
#' @export
pdf_signature_contents <- function(sig) {
  check_signature(sig)
  cpp_signature_contents_handle(sig$ptr)
}

#' Read the signed byte ranges of a PDF signature
#'
#' Returns the (offset, length) pairs that describe which
#' contiguous spans of the original PDF byte stream were covered
#' by the signing digest. A signature typically covers everything
#' except the signature's own `/Contents` entry, so a normal
#' signed PDF returns two pairs: bytes 0 to just-before-Contents,
#' and bytes just-after-Contents to end-of-file.
#'
#' Wraps `FPDFSignatureObj_GetByteRange`.
#'
#' @inheritParams pdf_signature_sub_filter
#' @return An integer matrix with `byte_range_pairs` rows and two
#'   columns named `offset` and `length` (both in bytes).
#' @seealso [pdf_signature_contents()].
#' @export
pdf_signature_byte_range <- function(sig) {
  check_signature(sig)
  cpp_signature_byte_range_handle(sig$ptr)
}
