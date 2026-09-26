// pdfium R package — form-field writers (Phase 7).
//
// The bulk of the per-field mutation is done by reusing the
// existing cpp_annot_set_string_value shim from annot_setters.cpp
// — PDFium's form-field value is just the /V entry on the
// widget annot dict. This file adds the one piece that doesn't fit
// elsewhere:
//
//   * cpp_page_flatten      — wraps FPDFPage_Flatten.
//
// Reading the existing /DV (for the clear-to-default path) goes
// through the existing cpp_annot_string_value reader; setting /V
// goes through cpp_annot_set_string_value. No new readers are
// needed.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_flatten.h"
#include "handle_validation.h"

namespace {

inline FPDF_PAGE page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

}  // namespace

// FPDFPage_Flatten returns:
//   FLATTEN_FAIL       = 0
//   FLATTEN_SUCCESS    = 1
//   FLATTEN_NOTHINGTODO = 2
// We surface the int code to R; the wrapper translates 0 to a
// clean R error. Modes:
//   FLAT_NORMALDISPLAY = 0  (display)
//   FLAT_PRINT         = 1
// [[Rcpp::export(name = "cpp_page_flatten")]]
int cpp_page_flatten(SEXP page_ptr, int mode_code) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  return FPDFPage_Flatten(page, mode_code);
}
