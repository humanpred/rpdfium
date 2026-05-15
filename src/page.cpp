// pdfium R package — page handle layer.
//
// FPDF_PAGE lifetime: a page is loaded from a document via
// FPDF_LoadPage(doc, index), and must be closed via FPDF_ClosePage
// before the document is closed. We wrap the FPDF_PAGE in an
// externalptr with a finalizer; the externalptr's `prot` slot holds
// the parent document's externalptr so R's GC cannot reclaim the
// document while any page is still live.
//
// Indexing: the FPDF_LoadPage page index is zero-based. The R-side
// API is one-based per R convention; R/page.R does the translation.

#include <Rcpp.h>
#include "fpdfview.h"

namespace {

void finalize_page(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) return;
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(ptr));
  if (page != nullptr) {
    FPDF_ClosePage(page);
    R_ClearExternalPtr(ptr);
  }
}

} // namespace

// [[Rcpp::export(name = "cpp_load_page")]]
SEXP cpp_load_page(SEXP doc_ptr, int page_index_zero_based) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) {
    Rcpp::stop("Document handle is closed.");
  }
  FPDF_PAGE page = FPDF_LoadPage(doc, page_index_zero_based);
  if (page == nullptr) {
    Rcpp::stop("FPDF_LoadPage returned NULL for page index %d",
               page_index_zero_based);
  }
  // tag = NilValue; prot = parent doc externalptr (keeps parent alive).
  SEXP ptr = PROTECT(R_MakeExternalPtr(page, R_NilValue, doc_ptr));
  R_RegisterCFinalizerEx(ptr, finalize_page, static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ptr;
}

// [[Rcpp::export(name = "cpp_close_page")]]
void cpp_close_page(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(ptr));
  if (page != nullptr) {
    FPDF_ClosePage(page);
    R_ClearExternalPtr(ptr);
  }
}

// [[Rcpp::export(name = "cpp_page_size")]]
Rcpp::NumericVector cpp_page_size(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(ptr));
  if (page == nullptr) {
    Rcpp::stop("Page handle is closed.");
  }
  double w = FPDF_GetPageWidthF(page);
  double h = FPDF_GetPageHeightF(page);
  return Rcpp::NumericVector::create(Rcpp::_["width"] = w,
                                     Rcpp::_["height"] = h);
}
