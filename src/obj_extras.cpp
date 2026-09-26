// pdfium R package — small additional page-object read accessors.
//
// Each function takes the same `obj_ptr` external pointer as
// src/objects.cpp and returns a single PDFium fact about the object.
// New accessors landed here (vs. extending objects.cpp) to keep the
// 0.1.0 read-completion diff localized to one file per topic. A
// future cleanup pass may fold these into objects.cpp.

#include <Rcpp.h>
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"
#include "native_raster.h"

namespace {

inline FPDF_PAGEOBJECT validated_pageobj(SEXP obj_ptr) {
  // Page objects are page-owned; their prot slot pins the parent
  // page externalptr. Closing the page strands the obj's address,
  // so we require the prot to still be alive.
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

inline FPDF_DOCUMENT validated_doc(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

// Convert a rendered pattern tile to a nativeRaster (row-major, see
// native_raster.h) and destroy the FPDF_BITMAP. PDFium rasterizes
// the tile in pattern space, so its first buffer row is the tile's
// *bottom* edge — the reverse of every other bitmap PDFium returns.
// Swap rows end-for-end so the result is top-down like the rest of
// the package's pdfium_bitmap objects.
SEXP pattern_tile_to_native(FPDF_BITMAP bmp) {
  if (bmp == nullptr) return R_NilValue;
  int w = FPDFBitmap_GetWidth(bmp);
  int h = FPDFBitmap_GetHeight(bmp);
  int stride = FPDFBitmap_GetStride(bmp);
  int format = FPDFBitmap_GetFormat(bmp);
  const uint8_t* src =
      static_cast<const uint8_t*>(FPDFBitmap_GetBuffer(bmp));
  Rcpp::IntegerMatrix m(h, w);
  pdfium_r::fill_bitmap_rowmajor(INTEGER(m), src, w, h, stride, format);
  FPDFBitmap_Destroy(bmp);
  int* px = INTEGER(m);
  for (int top = 0, bottom = h - 1; top < bottom; ++top, --bottom) {
    int* top_row = px + static_cast<size_t>(top) * w;
    std::swap_ranges(top_row, top_row + w,
                     px + static_cast<size_t>(bottom) * w);
  }
  return m;
}

}  // namespace

// One rasterized tile of the tiling pattern used as the object's
// fill (stroke = false) or stroke (stroke = true) colour, via
// FPDFPageObj_GetRendered{Fill,Stroke}Pattern (chromium/8066+).
// NULL when that colour is not a tiling pattern.
// [[Rcpp::export(name = "cpp_obj_rendered_pattern")]]
SEXP cpp_obj_rendered_pattern(SEXP doc_ptr, SEXP obj_ptr, bool stroke) {
  FPDF_DOCUMENT doc = validated_doc(doc_ptr);
  FPDF_PAGEOBJECT obj = validated_pageobj(obj_ptr);
  FPDF_BITMAP bmp = stroke
      ? FPDFPageObj_GetRenderedStrokePattern(doc, obj)
      : FPDFPageObj_GetRenderedFillPattern(doc, obj);
  return pattern_tile_to_native(bmp);
}

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
  if (!ok) {  // # nocov start  // GetRotatedBounds never fails on a page-owned obj
    return Rcpp::NumericVector::create(
      Rcpp::_["x1"] = NA_REAL, Rcpp::_["y1"] = NA_REAL,
      Rcpp::_["x2"] = NA_REAL, Rcpp::_["y2"] = NA_REAL,
      Rcpp::_["x3"] = NA_REAL, Rcpp::_["y3"] = NA_REAL,
      Rcpp::_["x4"] = NA_REAL, Rcpp::_["y4"] = NA_REAL
    );
  }  // # nocov end
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
