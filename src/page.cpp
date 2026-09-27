// pdfium R package — page handle layer.
//
// FPDF_PAGE lifetime: a page is loaded from a document via
// FPDF_LoadPage(doc, index), and must be closed via FPDF_ClosePage
// before the document is closed. make_page_handle() wraps the
// FPDF_PAGE in an externalptr with a finalizer and registers it under
// its document, which closes it first (handle_registry.h, ADR-025);
// the externalptr's `prot` slot holds the parent document's
// externalptr so R's GC cannot reclaim the document while any page is
// still live.
//
// Indexing: the FPDF_LoadPage page index is zero-based. The R-side
// API is one-based per R convention; R/page.R does the translation.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"  // for FPDFPage_GetRotation
#include "handle_registry.h"

// [[Rcpp::export(name = "cpp_load_page")]]
SEXP cpp_load_page(SEXP doc_ptr, int page_index_zero_based) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");  // # nocov  // R wrapper validates via checkmate
  }
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) {
    Rcpp::stop("Document handle is closed.");  // # nocov  // covered by test-defensive.R via representative shim
  }
  FPDF_PAGE page = FPDF_LoadPage(doc, page_index_zero_based);
  if (page == nullptr) {
    Rcpp::stop("FPDF_LoadPage returned NULL for page index %d",  // # nocov  // R wrapper bounds-checks page_num before this
               page_index_zero_based);
  }
  return pdfium_r::make_page_handle(page, doc_ptr);
}

// [[Rcpp::export(name = "cpp_close_page")]]
void cpp_close_page(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");  // # nocov  // R wrapper validates via checkmate
  }
  pdfium_r::release_page_handle(ptr);
}

// [[Rcpp::export(name = "cpp_page_size")]]
Rcpp::NumericVector cpp_page_size(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");  // # nocov  // R wrapper validates via checkmate
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(ptr));
  if (page == nullptr) {
    Rcpp::stop("Page handle is closed.");  // # nocov  // covered by test-defensive.R via representative shim
  }
  double w = FPDF_GetPageWidthF(page);
  double h = FPDF_GetPageHeightF(page);
  return Rcpp::NumericVector::create(Rcpp::_["width"] = w,
                                     Rcpp::_["height"] = h);
}

// [[Rcpp::export(name = "cpp_page_rotation")]]
int cpp_page_rotation(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");  // # nocov  // R wrapper validates via checkmate
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(ptr));
  if (page == nullptr) {
    Rcpp::stop("Page handle is closed.");  // # nocov  // covered by test-defensive.R via representative shim
  }
  // FPDFPage_GetRotation returns 0, 1, 2, 3 for 0°, 90°, 180°, 270°.
  // Convert to degrees so the R-facing value reads naturally.
  int code = FPDFPage_GetRotation(page);
  switch (code) {
    case 0: return 0;
    case 1: return 90;
    case 2: return 180;
    case 3: return 270;
    default: Rcpp::stop("Unexpected FPDFPage_GetRotation result: %d", code);  // # nocov  // PDFium guarantees 0..3
  }
}
