// pdfium R package — embedded-file (attachment) enumeration.
//
// PDFs can carry attached files (the /EmbeddedFile object stream).
// PDFium exposes these as FPDF_ATTACHMENT handles whose lifetime
// is owned by the parent document. Three readable facets:
//
//   FPDFDoc_GetAttachmentCount(doc)          -> int
//   FPDFDoc_GetAttachment(doc, index)        -> FPDF_ATTACHMENT
//   FPDFAttachment_GetName(att, buf, len)    -> UTF-16LE filename
//   FPDFAttachment_GetSubtype(att, buf, len) -> UTF-16LE MIME type
//   FPDFAttachment_GetFile(att, buf, len, &out) -> raw byte contents
//
// All UTF-16LE outputs are converted to UTF-8 via the shared
// pdfium_r::utf16le_to_utf8 helper.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_attachment.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

// Two-pass UTF-16LE buffer read for FPDFAttachment_GetName /
// FPDFAttachment_GetSubtype. Both return byte counts including a
// trailing UTF-16 NUL.
std::string read_utf16_attribute(
    FPDF_ATTACHMENT att,
    unsigned long (*getter)(FPDF_ATTACHMENT, FPDF_WCHAR*, unsigned long)) {
  unsigned long needed = getter(att, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  getter(att, reinterpret_cast<FPDF_WCHAR*>(buf.data()), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

}  // namespace

// [[Rcpp::export(name = "cpp_attachment_count")]]
int cpp_attachment_count(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  int n = FPDFDoc_GetAttachmentCount(doc);
  if (n < 0) {
    Rcpp::stop("FPDFDoc_GetAttachmentCount returned %d.", n);
  }
  return n;
}

// [[Rcpp::export(name = "cpp_attachments_list")]]
Rcpp::List cpp_attachments_list(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  int n = FPDFDoc_GetAttachmentCount(doc);
  if (n < 0) n = 0;
  Rcpp::CharacterVector names(n);
  Rcpp::CharacterVector mime(n);
  Rcpp::NumericVector size_bytes(n);
  for (int i = 0; i < n; ++i) {
    FPDF_ATTACHMENT att = FPDFDoc_GetAttachment(doc, i);
    if (att == nullptr) {
      names[i] = NA_STRING;
      mime[i]  = NA_STRING;
      size_bytes[i] = NA_REAL;
      continue;
    }
    names[i] = read_utf16_attribute(att, FPDFAttachment_GetName);
    mime[i]  = read_utf16_attribute(att, FPDFAttachment_GetSubtype);
    unsigned long out_buflen = 0;
    if (FPDFAttachment_GetFile(att, nullptr, 0, &out_buflen)) {
      size_bytes[i] = static_cast<double>(out_buflen);
    } else {
      size_bytes[i] = NA_REAL;
    }
  }
  return Rcpp::List::create(
      Rcpp::_["name"]       = names,
      Rcpp::_["mime_type"]  = mime,
      Rcpp::_["size_bytes"] = size_bytes);
}

// [[Rcpp::export(name = "cpp_attachment_data")]]
Rcpp::RawVector cpp_attachment_data(SEXP doc_ptr, int index_zero) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_ATTACHMENT att = FPDFDoc_GetAttachment(doc, index_zero);
  if (att == nullptr) {
    Rcpp::stop("FPDFDoc_GetAttachment returned NULL for index %d.",
               index_zero);
  }
  unsigned long needed = 0;
  if (!FPDFAttachment_GetFile(att, nullptr, 0, &needed)) {
    Rcpp::stop("FPDFAttachment_GetFile reports unreadable contents.");
  }
  Rcpp::RawVector out(static_cast<R_xlen_t>(needed));
  if (needed > 0) {
    unsigned long got = 0;
    FPDFAttachment_GetFile(att, &out[0], needed, &got);
  }
  return out;
}
