// pdfium R package — text-object metadata accessors.
//
// Phase 1 ships only the font-size getter; broader text APIs
// (content, positioning, font metadata) are Phase 2/3.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"

// [[Rcpp::export(name = "cpp_text_font_size")]]
double cpp_text_font_size(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) Rcpp::stop("Expected an external pointer.");
  FPDF_PAGEOBJECT obj = static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) Rcpp::stop("Page-object handle is closed.");
  float size = 0.0f;
  FPDF_BOOL ok = FPDFTextObj_GetFontSize(obj, &size);
  if (!ok) return NA_REAL;
  return static_cast<double>(size);
}
