// pdfium R package — small additional page-object read accessors.
//
// Each function takes the same `obj_ptr` external pointer as
// src/objects.cpp and returns a single PDFium fact about the object.
// New accessors landed here (vs. extending objects.cpp) to keep the
// 0.1.0 read-completion diff localized to one file per topic. A
// future cleanup pass may fold these into objects.cpp.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"

namespace {

inline FPDF_PAGEOBJECT validated_pageobj(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGEOBJECT obj =
      static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) {
    Rcpp::stop("Page-object handle is closed.");
  }
  return obj;
}

}  // namespace

// Path-specific: line cap. Returns FPDF_LINECAP_BUTT (0),
// FPDF_LINECAP_ROUND (1), or FPDF_LINECAP_PROJECTING_SQUARE (2).
// [[Rcpp::export(name = "cpp_obj_line_cap")]]
int cpp_obj_line_cap(SEXP obj_ptr) {
  return FPDFPageObj_GetLineCap(validated_pageobj(obj_ptr));
}

// Path-specific: line join. Returns FPDF_LINEJOIN_MITER (0),
// FPDF_LINEJOIN_ROUND (1), or FPDF_LINEJOIN_BEVEL (2).
// [[Rcpp::export(name = "cpp_obj_line_join")]]
int cpp_obj_line_join(SEXP obj_ptr) {
  return FPDFPageObj_GetLineJoin(validated_pageobj(obj_ptr));
}

// True if FPDFPageObj_HasTransparency reports any source of alpha
// blending on this object (fill/stroke alpha < 255, soft mask, etc.).
// [[Rcpp::export(name = "cpp_obj_has_transparency")]]
bool cpp_obj_has_transparency(SEXP obj_ptr) {
  return FPDFPageObj_HasTransparency(validated_pageobj(obj_ptr)) != 0;
}

// Active flag. Inactive page-objects are skipped during rendering but
// still enumerated. Returns NA when PDFium reports failure.
// [[Rcpp::export(name = "cpp_obj_is_active")]]
SEXP cpp_obj_is_active(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = validated_pageobj(obj_ptr);
  FPDF_BOOL active = 0;
  FPDF_BOOL ok = FPDFPageObj_GetIsActive(obj, &active);
  if (!ok) return Rcpp::wrap(NA_LOGICAL);
  return Rcpp::wrap(active != 0);
}

// Rotated bounds as the four quadpoints of the object's true (possibly
// rotated) bounding rectangle. Returns an 8-element named numeric
// vector: x1, y1 (lower-left), x2, y2 (lower-right), x3, y3 (upper-right),
// x4, y4 (upper-left). For axis-aligned objects this is equivalent to
// FPDFPageObj_GetBounds; for rotated text or images the rotated quad is
// strictly tighter.
// [[Rcpp::export(name = "cpp_obj_rotated_bounds")]]
Rcpp::NumericVector cpp_obj_rotated_bounds(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = validated_pageobj(obj_ptr);
  FS_QUADPOINTSF q;
  FPDF_BOOL ok = FPDFPageObj_GetRotatedBounds(obj, &q);
  if (!ok) {
    return Rcpp::NumericVector::create(
      Rcpp::_["x1"] = NA_REAL, Rcpp::_["y1"] = NA_REAL,
      Rcpp::_["x2"] = NA_REAL, Rcpp::_["y2"] = NA_REAL,
      Rcpp::_["x3"] = NA_REAL, Rcpp::_["y3"] = NA_REAL,
      Rcpp::_["x4"] = NA_REAL, Rcpp::_["y4"] = NA_REAL
    );
  }
  return Rcpp::NumericVector::create(
    Rcpp::_["x1"] = static_cast<double>(q.x1),
    Rcpp::_["y1"] = static_cast<double>(q.y1),
    Rcpp::_["x2"] = static_cast<double>(q.x2),
    Rcpp::_["y2"] = static_cast<double>(q.y2),
    Rcpp::_["x3"] = static_cast<double>(q.x3),
    Rcpp::_["y3"] = static_cast<double>(q.y3),
    Rcpp::_["x4"] = static_cast<double>(q.x4),
    Rcpp::_["y4"] = static_cast<double>(q.y4)
  );
}
