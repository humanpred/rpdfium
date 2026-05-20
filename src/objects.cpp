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
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"

namespace {

inline FPDF_PAGE objs_page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

inline FPDF_PAGEOBJECT objs_obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// [[Rcpp::export(name = "cpp_page_object_count")]]
int cpp_page_object_count(SEXP page_ptr) {
  return FPDFPage_CountObjects(objs_page_from_ptr(page_ptr));
}

// [[Rcpp::export(name = "cpp_page_get_object")]]
SEXP cpp_page_get_object(SEXP page_ptr, int index_zero_based) {
  FPDF_PAGE page = objs_page_from_ptr(page_ptr);
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
  return FPDFPageObj_GetType(objs_obj_from_ptr(obj_ptr));
}

// [[Rcpp::export(name = "cpp_obj_bounds")]]
Rcpp::NumericVector cpp_obj_bounds(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = objs_obj_from_ptr(obj_ptr);
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

namespace {
// Common helper for the four-channel color getters. Returns a length-4
// NumericVector (red, green, blue, alpha) of integers 0-255 stored as
// doubles. Returns a 4-NA vector when the getter reports no color set.
Rcpp::NumericVector pageobj_color(
    FPDF_PAGEOBJECT obj,
    FPDF_BOOL (*getter)(FPDF_PAGEOBJECT, unsigned int*, unsigned int*,
                        unsigned int*, unsigned int*),
    const char* getter_name) {
  unsigned int r = 0, g = 0, b = 0, a = 0;
  FPDF_BOOL ok = getter(obj, &r, &g, &b, &a);
  if (!ok) {
    return Rcpp::NumericVector::create(
      Rcpp::_["red"]   = NA_REAL,
      Rcpp::_["green"] = NA_REAL,
      Rcpp::_["blue"]  = NA_REAL,
      Rcpp::_["alpha"] = NA_REAL
    );
  }
  // Suppress unused-parameter warning if Rcpp::stop is optimised away.
  (void) getter_name;
  return Rcpp::NumericVector::create(
    Rcpp::_["red"]   = static_cast<double>(r),
    Rcpp::_["green"] = static_cast<double>(g),
    Rcpp::_["blue"]  = static_cast<double>(b),
    Rcpp::_["alpha"] = static_cast<double>(a)
  );
}
}  // namespace

// [[Rcpp::export(name = "cpp_obj_stroke_color")]]
Rcpp::NumericVector cpp_obj_stroke_color(SEXP obj_ptr) {
  return pageobj_color(objs_obj_from_ptr(obj_ptr),
                       FPDFPageObj_GetStrokeColor,
                       "FPDFPageObj_GetStrokeColor");
}

// [[Rcpp::export(name = "cpp_obj_fill_color")]]
Rcpp::NumericVector cpp_obj_fill_color(SEXP obj_ptr) {
  return pageobj_color(objs_obj_from_ptr(obj_ptr),
                       FPDFPageObj_GetFillColor,
                       "FPDFPageObj_GetFillColor");
}

// [[Rcpp::export(name = "cpp_obj_stroke_width")]]
double cpp_obj_stroke_width(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = objs_obj_from_ptr(obj_ptr);
  float width = 0.0f;
  FPDF_BOOL ok = FPDFPageObj_GetStrokeWidth(obj, &width);
  if (!ok) return NA_REAL;
  return static_cast<double>(width);
}

// [[Rcpp::export(name = "cpp_obj_matrix")]]
Rcpp::NumericVector cpp_obj_matrix(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = objs_obj_from_ptr(obj_ptr);
  FS_MATRIX m;
  FPDF_BOOL ok = FPDFPageObj_GetMatrix(obj, &m);
  if (!ok) Rcpp::stop("FPDFPageObj_GetMatrix failed for this object.");
  return Rcpp::NumericVector::create(
    Rcpp::_["a"] = static_cast<double>(m.a),
    Rcpp::_["b"] = static_cast<double>(m.b),
    Rcpp::_["c"] = static_cast<double>(m.c),
    Rcpp::_["d"] = static_cast<double>(m.d),
    Rcpp::_["e"] = static_cast<double>(m.e),
    Rcpp::_["f"] = static_cast<double>(m.f)
  );
}

// [[Rcpp::export(name = "cpp_obj_dash_count")]]
int cpp_obj_dash_count(SEXP obj_ptr) {
  return FPDFPageObj_GetDashCount(objs_obj_from_ptr(obj_ptr));
}

// [[Rcpp::export(name = "cpp_obj_dash_array")]]
Rcpp::NumericVector cpp_obj_dash_array(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = objs_obj_from_ptr(obj_ptr);
  int n = FPDFPageObj_GetDashCount(obj);
  if (n <= 0) return Rcpp::NumericVector(0);
  std::vector<float> buf(static_cast<size_t>(n), 0.0f);
  FPDF_BOOL ok = FPDFPageObj_GetDashArray(obj, buf.data(),
                                          static_cast<size_t>(n));
  if (!ok) Rcpp::stop("FPDFPageObj_GetDashArray failed for this object.");
  Rcpp::NumericVector out(n);
  for (int i = 0; i < n; ++i) out[i] = static_cast<double>(buf[i]);
  return out;
}

// [[Rcpp::export(name = "cpp_obj_dash_phase")]]
double cpp_obj_dash_phase(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = objs_obj_from_ptr(obj_ptr);
  float phase = 0.0f;
  FPDF_BOOL ok = FPDFPageObj_GetDashPhase(obj, &phase);
  if (!ok) return NA_REAL;
  return static_cast<double>(phase);
}
