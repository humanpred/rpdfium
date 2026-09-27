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
// belongs to a parent page, to an annotation when the form sits in its
// appearance stream, or to an enclosing form. Each nested object's
// externalptr carries the form's externalptr in its `prot` slot, so GC
// ordering cannot invalidate a live nested reference, and
// validate_handle() refuses the object once the form, or anything that
// owns the form, is closed (ADR-029).

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"

namespace {

FPDF_PAGEOBJECT form_from_ptr(SEXP form_ptr) {
  // Form XObject page-objects are themselves owned by a page, an
  // annotation or another form; their prot slot pins that owner's
  // externalptr.
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
SEXP cpp_form_get_object(SEXP form_ptr, int index_zero_based) {
  FPDF_PAGEOBJECT form = form_from_ptr(form_ptr);
  FPDF_PAGEOBJECT obj =
      FPDFFormObj_GetObject(form, static_cast<unsigned long>(index_zero_based));
  if (obj == nullptr) {
    Rcpp::stop("FPDFFormObj_GetObject returned NULL for index %d.",
               index_zero_based);
  }
  // No finalizer: nested page-object lifetime is owned by the form.
  return R_MakeExternalPtr(obj, R_NilValue, form_ptr);
}
