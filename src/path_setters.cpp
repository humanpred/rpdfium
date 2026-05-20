// pdfium R package — path-geometry appenders (Phase 4).
//
// PDFium exposes only append-style mutation on existing path
// page-objects:
//
//   FPDFPath_MoveTo(path, x, y)
//   FPDFPath_LineTo(path, x, y)
//   FPDFPath_BezierTo(path, x1, y1, x2, y2, x3, y3)
//   FPDFPath_Close(path)
//
// There is no public segment-removal or segment-replacement API.
// "Rebuilding" a path means creating a new path object (Phase 5),
// appending the desired segments via these shims, and removing the
// original page object — the workflow is composed at the R layer.
//
// All shims share the obj_from_ptr helper that requires the parent
// page externalptr (in the obj's prot slot) to still be alive —
// closing the page after taking an obj reference raises a clean R
// error instead of dereferencing freed memory (handle_validation.h,
// ADR-020 §4).

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"

namespace {

inline FPDF_PAGEOBJECT obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// [[Rcpp::export(name = "cpp_path_move_to")]]
bool cpp_path_move_to(SEXP obj_ptr, double x, double y) {
  return FPDFPath_MoveTo(obj_from_ptr(obj_ptr),
                          static_cast<float>(x),
                          static_cast<float>(y)) != 0;
}

// [[Rcpp::export(name = "cpp_path_line_to")]]
bool cpp_path_line_to(SEXP obj_ptr, double x, double y) {
  return FPDFPath_LineTo(obj_from_ptr(obj_ptr),
                          static_cast<float>(x),
                          static_cast<float>(y)) != 0;
}

// [[Rcpp::export(name = "cpp_path_bezier_to")]]
bool cpp_path_bezier_to(SEXP obj_ptr,
                          double x1, double y1,
                          double x2, double y2,
                          double x3, double y3) {
  return FPDFPath_BezierTo(obj_from_ptr(obj_ptr),
                            static_cast<float>(x1),
                            static_cast<float>(y1),
                            static_cast<float>(x2),
                            static_cast<float>(y2),
                            static_cast<float>(x3),
                            static_cast<float>(y3)) != 0;
}

// [[Rcpp::export(name = "cpp_path_close")]]
bool cpp_path_close(SEXP obj_ptr) {
  return FPDFPath_Close(obj_from_ptr(obj_ptr)) != 0;
}
