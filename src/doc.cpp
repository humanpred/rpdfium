// pdfium R package — document-level readers (page labels and
// permissions). Bookmark enumeration moved to bookmark_handles.cpp
// when pdf_doc_bookmarks() switched to the handle-list shape; this
// file now hosts the remaining flat-data readers that take a
// FPDF_DOCUMENT and return a single value or vector.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"
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

}  // namespace

// [[Rcpp::export(name = "cpp_page_label")]]
std::string cpp_page_label(SEXP doc_ptr, int page_index_zero) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  unsigned long needed =
      FPDF_GetPageLabel(doc, page_index_zero, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDF_GetPageLabel(doc, page_index_zero, buf.data(), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// [[Rcpp::export(name = "cpp_doc_permissions")]]
double cpp_doc_permissions(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  // FPDF_GetDocPermissions returns an unsigned 32-bit integer.
  // Promote to double so R sees the full 32-bit range (R's integer
  // is 32-bit signed and cannot hold 0xFFFFFFFF). The R wrapper
  // bit-decodes this into a per-flag named logical vector.
  return static_cast<double>(FPDF_GetDocPermissions(doc));
}
