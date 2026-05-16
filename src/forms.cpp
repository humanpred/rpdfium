// pdfium R package — Form XObject enumeration.
//
// A PDF Form XObject is a self-contained subgraph: a sub-page that
// holds its own page-object collection plus a /Matrix transformation
// applied when the form is drawn on a page. PDFium exposes the
// nested objects through:
//
//   FPDFFormObj_CountObjects(form) -> int  (-1 on error)
//   FPDFFormObj_GetObject(form, idx) -> FPDF_PAGEOBJECT (NULL on error)
//
// Nested page-object lifetimes are tied to the form, which in turn
// belongs to a parent page. The R wrapper threads the parent page's
// externalptr through to each nested obj so GC ordering cannot
// invalidate a live nested reference; this file's externalptrs carry
// that page pointer in the `prot` slot, mirroring the pattern in
// objects.cpp.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"

namespace {

FPDF_PAGEOBJECT form_from_ptr(SEXP form_ptr) {
  if (TYPEOF(form_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the form object.");
  }
  FPDF_PAGEOBJECT form =
      static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(form_ptr));
  if (form == nullptr) Rcpp::stop("Form-object handle is closed.");
  return form;
}

}  // namespace

// [[Rcpp::export(name = "cpp_form_object_count")]]
int cpp_form_object_count(SEXP form_ptr) {
  FPDF_PAGEOBJECT form = form_from_ptr(form_ptr);
  int n = FPDFFormObj_CountObjects(form);
  if (n < 0) {
    Rcpp::stop("FPDFFormObj_CountObjects returned %d "
               "(not a Form XObject?).", n);
  }
  return n;
}

// [[Rcpp::export(name = "cpp_form_get_object")]]
SEXP cpp_form_get_object(SEXP form_ptr, SEXP page_ptr,
                         int index_zero_based) {
  FPDF_PAGEOBJECT form = form_from_ptr(form_ptr);
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the parent page.");
  }
  if (R_ExternalPtrAddr(page_ptr) == nullptr) {
    Rcpp::stop("Parent page handle is closed.");
  }
  FPDF_PAGEOBJECT obj =
      FPDFFormObj_GetObject(form, static_cast<unsigned long>(index_zero_based));
  if (obj == nullptr) {
    Rcpp::stop("FPDFFormObj_GetObject returned NULL for index %d.",
               index_zero_based);
  }
  // No finalizer: nested page-object lifetime is owned by the form,
  // which in turn lives as long as the parent page. We keep the
  // page's externalptr in `prot` so GC cannot reclaim the page (and
  // therefore the form and its nested children) while any nested-
  // object reference is live.
  return R_MakeExternalPtr(obj, R_NilValue, page_ptr);
}
