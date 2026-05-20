# Digital-signature accessors. PDF signatures (PDF spec 12.8)
# carry one or more cryptographic signing operations over the
# document's byte stream. PDFium gives us per-signature metadata
# plus access to the signature's contents (the PKCS#7 / PKCS#1
# blob) and the signed byte range (which spans the document are
# covered by the digest).
#
# This module exposes the read side. We don't ship signature
# *verification* in v0.1.0 - that's a PKI cryptography concern
# (download CRLs, check timestamp authority, validate cert chain
# against trust anchors) that belongs in a downstream package
# layered on top of, e.g., openssl::pkcs7_verify().

#' List the digital signatures attached to a PDF document
#'
#' Returns a tibble row per signature object in the document.
#' Wraps `FPDF_GetSignatureCount`, `FPDF_GetSignatureObject`, and
#' the `FPDFSignatureObj_*` scalar accessors.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @return A tibble with columns:
#'   * `signature_index` integer - 1-based; pass to
#'     [pdf_signature_contents()] / [pdf_signature_byte_range()].
#'   * `sub_filter` character - the signature's `/SubFilter`
#'     value, e.g. `"adbe.pkcs7.detached"`, `"ETSI.CAdES.detached"`,
#'     `"adbe.x509.rsa_sha1"`. ASCII.
#'   * `reason` character - UTF-8 reason / comment string,
#'     attached when the signer wrote one. Empty if absent.
#'   * `time` character - signing time in PDF date format
#'     (`"D:YYYYMMDDHHmmSS+HH'mm'"`). Empty if the signature
#'     defers to the timestamp inside the PKCS#7 blob. Pass to
#'     [pdf_parse_date()] for a POSIXct.
#'   * `doc_mdp_permission` integer - 1, 2, or 3 (PDF DocMDP
#'     permission level: no changes / form-fill only / form-fill
#'     + annotations + signing fields). `NA` when no DocMDP entry
#'     is present.
#'   * `contents_size` integer - byte length of the signature
#'     blob (DER-encoded PKCS#1 or PKCS#7).
#'   * `byte_range_pairs` integer - number of (offset, length)
#'     pairs covered by the signed digest. Pass `signature_index`
#'     to [pdf_signature_byte_range()] for the actual pairs.
#'
#' Returns a 0-row tibble of the same schema when the document
#' has no signatures.
#'
#' @seealso [pdf_signature_contents()] for the raw PKCS#7 / PKCS#1
#'   bytes, [pdf_signature_byte_range()] for the signed byte
#'   ranges, [pdf_parse_date()] for parsing the `time` column.
#' @export
pdf_signatures <- function(doc) {
  doc <- as_open_doc(doc)
  raw <- cpp_signatures_list(doc$ptr)
  tibble::tibble(
    signature_index    = seq_along(raw$sub_filter),
    sub_filter         = raw$sub_filter,
    reason             = raw$reason,
    time               = raw$time,
    doc_mdp_permission = as.integer(raw$doc_mdp_permission),
    contents_size      = as.integer(raw$contents_size),
    byte_range_pairs   = as.integer(raw$byte_range_pairs)
  )
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
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @param signature_index One-based signature index (default `1`),
#'   as listed by [pdf_signatures()].
#' @return A raw vector of the signature blob.
#' @seealso [pdf_signatures()], [pdf_signature_byte_range()].
#' @export
pdf_signature_contents <- function(doc, signature_index = 1L) {
  checkmate::assert_count(signature_index, positive = TRUE)
  doc <- as_open_doc(doc)
  cpp_signature_contents(doc$ptr, as.integer(signature_index) - 1L)
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
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @param signature_index One-based signature index (default `1`),
#'   as listed by [pdf_signatures()].
#' @return An integer matrix with `byte_range_pairs` rows and two
#'   columns named `offset` and `length` (both in bytes).
#' @seealso [pdf_signatures()], [pdf_signature_contents()].
#' @export
pdf_signature_byte_range <- function(doc, signature_index = 1L) {
  checkmate::assert_count(signature_index, positive = TRUE)
  doc <- as_open_doc(doc)
  cpp_signature_byte_range(doc$ptr, as.integer(signature_index) - 1L)
}
