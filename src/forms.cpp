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
// belongs to a parent page, or to an annotation when the form sits in
// its appearance stream. The R wrapper threads that owner's
// externalptr through to each nested obj so GC ordering cannot
// invalidate a live nested reference; this file's externalptrs carry
// the owner pointer in the `prot` slot, mirroring the pattern in
// objects.cpp.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"

namespace {

FPDF_PAGEOBJECT form_from_ptr(SEXP form_ptr) {
  // Form XObject page-objects are themselves owned by a page or an
  // annotation; their prot slot pins that owner's externalptr.
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(form_ptr, "Form page-object",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// [[Rcpp::export(name = "cpp_form_object_count")]]
int cpp_form_object_count(SEXP form_ptr) {
  FPDF_PAGEOBJECT form = form_from_ptr(form_ptr);
  int n = FPDFFormObj_CountObjects(form);
  if (n < 0) {
    Rcpp::stop("FPDFFormObj_CountObjects returned %d "  // # nocov  // R wrapper restricts to Form XObject types before reaching the shim
               "(not a Form XObject?).", n);
  }
  return n;
}

// [[Rcpp::export(name = "cpp_form_get_object")]]
SEXP cpp_form_get_object(SEXP form_ptr, SEXP owner_ptr,
                         int index_zero_based) {
  FPDF_PAGEOBJECT form = form_from_ptr(form_ptr);
  if (TYPEOF(owner_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the form's owner.");  // # nocov  // R wrapper threads the owning page / annotation externalptr
  }
  if (R_ExternalPtrAddr(owner_ptr) == nullptr) {
    Rcpp::stop("The form's owner handle is closed.");  // # nocov  // owner is the form's prot or its page, both checked before this
  }
  FPDF_PAGEOBJECT obj =
      FPDFFormObj_GetObject(form, static_cast<unsigned long>(index_zero_based));
  if (obj == nullptr) {
    Rcpp::stop("FPDFFormObj_GetObject returned NULL for index %d.",
               index_zero_based);
  }
  // No finalizer: nested page-object lifetime is owned by the form,
  // which in turn lives as long as its page or annotation. We keep
  // that owner's externalptr in `prot` so GC cannot reclaim it (and
  // therefore the form and its nested children) while any nested-
  // object reference is live, and so validate_handle() refuses the
  // child once the owner handle is cleared.
  return R_MakeExternalPtr(obj, R_NilValue, owner_ptr);
}
