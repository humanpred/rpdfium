// pdfium R package — page-object enumeration layer.
//
// FPDF_PAGEOBJECT pointers are not separately allocated handles - they
// point into the parent FPDF_PAGE's internal data structures. A page
// object lives exactly as long as its parent page. We therefore wrap
// each FPDF_PAGEOBJECT in an externalptr WITHOUT a finalizer, and
// store the parent page's externalptr in the `prot` slot so R's GC
// cannot reclaim the page while any object reference remains live.
//
// PDFium's FPDFPageObj_GetType returns an enum:
//   FPDF_PAGEOBJ_UNKNOWN = 0
//   FPDF_PAGEOBJ_TEXT    = 1
//   FPDF_PAGEOBJ_PATH    = 2
//   FPDF_PAGEOBJ_IMAGE   = 3
//   FPDF_PAGEOBJ_SHADING = 4
//   FPDF_PAGEOBJ_FORM    = 5
// The R wrapper converts these to human-readable strings.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"

// [[Rcpp::export(name = "cpp_page_object_count")]]
int cpp_page_object_count(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) {
    Rcpp::stop("Page handle is closed.");
  }
  return FPDFPage_CountObjects(page);
}

// [[Rcpp::export(name = "cpp_page_get_object")]]
SEXP cpp_page_get_object(SEXP page_ptr, int index_zero_based) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) {
    Rcpp::stop("Page handle is closed.");
  }
  FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page, index_zero_based);
  if (obj == nullptr) {
    Rcpp::stop("FPDFPage_GetObject returned NULL for object index %d",
               index_zero_based);
  }
  // No finalizer: page object lifetime is tied to the parent page.
  // prot = page's externalptr so the page cannot be GC'd while this
  // object reference is live.
  return R_MakeExternalPtr(obj, R_NilValue, page_ptr);
}

// [[Rcpp::export(name = "cpp_obj_type")]]
int cpp_obj_type(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGEOBJECT obj = static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) {
    Rcpp::stop("Page-object handle is closed.");
  }
  return FPDFPageObj_GetType(obj);
}

// [[Rcpp::export(name = "cpp_obj_bounds")]]
Rcpp::NumericVector cpp_obj_bounds(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGEOBJECT obj = static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) {
    Rcpp::stop("Page-object handle is closed.");
  }
  float left = 0.0f, bottom = 0.0f, right = 0.0f, top = 0.0f;
  FPDF_BOOL ok = FPDFPageObj_GetBounds(obj, &left, &bottom, &right, &top);
  if (!ok) Rcpp::stop("FPDFPageObj_GetBounds failed for this object.");
  return Rcpp::NumericVector::create(
    Rcpp::_["left"]   = static_cast<double>(left),
    Rcpp::_["bottom"] = static_cast<double>(bottom),
    Rcpp::_["right"]  = static_cast<double>(right),
    Rcpp::_["top"]    = static_cast<double>(top)
  );
}
