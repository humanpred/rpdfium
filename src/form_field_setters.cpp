// pdfium R package — form-field writers (Phase 7).
//
// The bulk of the per-field mutation is done by reusing the
// existing cpp_annot_set_string_value shim from annot_setters.cpp
// — PDFium's form-field value is just the /V entry on the
// widget annot dict. This file adds the two pieces that don't fit
// elsewhere:
//
//   * cpp_page_flatten      — wraps FPDFPage_Flatten.
//   * cpp_form_field_set_ap_dirty
//       — manually marks the widget annot as needing AP regen
//         after a /V change, so the next render / save shows the
//         new value. Reuses the same SetRect-to-current-rect
//         trick that cpp_page_refresh_annot_aps uses.
//
// Reading the existing /DV (for the clear-to-default path) goes
// through the existing cpp_annot_string_value reader; setting /V
// goes through cpp_annot_set_string_value. No new readers are
// needed.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_flatten.h"
#include "handle_validation.h"

namespace {

inline FPDF_PAGE page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

inline FPDF_ANNOTATION annot_from_ptr(SEXP annot_ptr) {
  return static_cast<FPDF_ANNOTATION>(
      pdfium_r::validate_handle(annot_ptr, "Annotation",
                                  /*require_prot_alive=*/true));
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

// Force PDFium to regenerate this single annotation's AP stream
// on the next render / save by setting the rect to its current
// value (FPDFAnnot_SetRect flips the AP-dirty flag even when the
// rect is unchanged — same trick as cpp_page_refresh_annot_aps,
// but scoped to one annot so callers don't pay the cost of
// walking every annot on the page just to flush one /V change).
// [[Rcpp::export(name = "cpp_annot_touch_ap")]]
bool cpp_annot_touch_ap(SEXP annot_ptr) {
  FPDF_ANNOTATION a = annot_from_ptr(annot_ptr);
  FS_RECTF r;
  if (!FPDFAnnot_GetRect(a, &r)) {
    return false;
  }
  return FPDFAnnot_SetRect(a, &r) != 0;
}
