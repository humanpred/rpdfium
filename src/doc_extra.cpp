// pdfium R package — extra doc-level wrappers introduced in the
// phase-6 polish pass. Specifically:
//
//   FPDF_GetFileIdentifier    -> pdf_file_id(doc, type)
//   FPDFDoc_GetPageMode       -> pdf_doc_page_mode(doc)
//
// Both are document-scoped scalar accessors that fit alongside
// pdf_doc_info() / pdf_doc_meta() but don't share enough code to
// live in src/document.cpp. Kept here so future extras (e.g.
// FPDF_GetSecurityHandlerRevision, viewer-prefs accessors) can
// pile on without bloating the metadata module.

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"
#include "fpdf_ext.h"

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

}  // namespace

// [[Rcpp::export(name = "cpp_doc_file_id")]]
Rcpp::RawVector cpp_doc_file_id(SEXP doc_ptr, int id_type) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  // PDFium's FPDF_FILEIDTYPE is 0 (permanent) or 1 (changing). The
  // R wrapper validates the value before calling in.
  unsigned long needed = FPDF_GetFileIdentifier(
      doc, static_cast<FPDF_FILEIDTYPE>(id_type), nullptr, 0);
  if (needed <= 1) return Rcpp::RawVector(0);  // empty + NUL
  std::vector<unsigned char> buf(needed);
  FPDF_GetFileIdentifier(doc,
                          static_cast<FPDF_FILEIDTYPE>(id_type),
                          buf.data(), needed);
  // Strip the trailing NUL byte.
  size_t n = (needed >= 1 ? needed - 1 : needed);
  Rcpp::RawVector out(static_cast<R_xlen_t>(n));
  for (size_t i = 0; i < n; ++i) out[i] = buf[i];
  return out;
}

// [[Rcpp::export(name = "cpp_doc_page_mode")]]
int cpp_doc_page_mode(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  return FPDFDoc_GetPageMode(doc);
}
