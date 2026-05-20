// pdfium R package — document health / security / structural
// readers. Five small accessors that round out the doc-level
// surface for v0.1.0:
//
//   FPDF_GetSecurityHandlerRevision           pdf_doc_security()
//   FPDF_GetDocUserPermissions                pdf_doc_user_permissions()
//   FPDF_DocumentHasValidCrossReferenceTable  pdf_doc_xref_valid()
//   FPDF_GetTrailerEnds                       pdf_doc_trailer_ends()
//   FPDF_GetPageSizeByIndexF                  pdf_page_size(doc, page_num)
//                                              (alternate "no page load" path)
//
// Each is small enough that they share one file. The security
// revision + user permissions are useful for encryption inspectors;
// xref validity + trailer ends matter for repair workflows /
// incremental-update analysis.

#include <Rcpp.h>
#include <vector>
#include "fpdfview.h"

namespace {

FPDF_DOCUMENT health_doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

}  // namespace

// FPDF_GetSecurityHandlerRevision returns 0 for unencrypted PDFs;
// 2 for the original 40-bit RC4 handler; 3 for 128-bit RC4; 4 for
// AES; 5/6 for AES-256 (PDF 1.7 Adobe Extension / PDF 2.0). -1 on
// failure.
// [[Rcpp::export(name = "cpp_doc_security_revision")]]
int cpp_doc_security_revision(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = health_doc_from_ptr(doc_ptr);
  return FPDF_GetSecurityHandlerRevision(doc);
}

// FPDF_GetDocUserPermissions returns the "user" subset of the
// 32-bit permission bitmask (subset of FPDF_GetDocPermissions).
// Surfaced as double so R sees the full unsigned-32 range; the R
// wrapper bit-decodes into named logicals.
// [[Rcpp::export(name = "cpp_doc_user_permissions")]]
double cpp_doc_user_permissions(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = health_doc_from_ptr(doc_ptr);
  return static_cast<double>(FPDF_GetDocUserPermissions(doc));
}

// FPDF_DocumentHasValidCrossReferenceTable returns FALSE on a PDF
// whose xref was missing or had to be rebuilt by PDFium.
// [[Rcpp::export(name = "cpp_doc_xref_valid")]]
bool cpp_doc_xref_valid(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = health_doc_from_ptr(doc_ptr);
  return FPDF_DocumentHasValidCrossReferenceTable(doc) != 0;
}

// FPDF_GetTrailerEnds returns byte offsets where each "%%EOF"
// trailer marker ends. Most PDFs have exactly one; incremental
// updates produce more.
// [[Rcpp::export(name = "cpp_doc_trailer_ends")]]
Rcpp::IntegerVector cpp_doc_trailer_ends(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = health_doc_from_ptr(doc_ptr);
  unsigned long n = FPDF_GetTrailerEnds(doc, nullptr, 0);
  if (n == 0) return Rcpp::IntegerVector();
  std::vector<unsigned int> buf(n);
  FPDF_GetTrailerEnds(doc, buf.data(), n);
  Rcpp::IntegerVector out(static_cast<R_xlen_t>(n));
  for (unsigned long i = 0; i < n; ++i) {
    // PDFium gives unsigned 32-bit offsets. R's integer is signed
    // 32-bit; convert via double to NA on overflow so very large
    // files (>2GB) come back NA rather than wrap.
    unsigned int v = buf[i];
    if (v > static_cast<unsigned int>(INT_MAX)) {
      out[i] = NA_INTEGER;
    } else {
      out[i] = static_cast<int>(v);
    }
  }
  return out;
}

// FPDF_GetPageSizeByIndexF reads the page's width/height without
// loading the page. Cheaper than pdf_page_load + pdf_page_size for
// callers that just want the dimensions of every page.
// [[Rcpp::export(name = "cpp_doc_page_size_by_index")]]
Rcpp::NumericVector cpp_doc_page_size_by_index(SEXP doc_ptr,
                                                int page_index_zero) {
  FPDF_DOCUMENT doc = health_doc_from_ptr(doc_ptr);
  FS_SIZEF sz;
  if (!FPDF_GetPageSizeByIndexF(doc, page_index_zero, &sz)) {
    return Rcpp::NumericVector::create(Rcpp::_["width"]  = NA_REAL,
                                        Rcpp::_["height"] = NA_REAL);
  }
  return Rcpp::NumericVector::create(Rcpp::_["width"]  = sz.width,
                                      Rcpp::_["height"] = sz.height);
}
