// pdfium R package — path-segment readout.
//
// PDFium stores a path as a flat list of points, each tagged
// moveto / lineto / bezierto plus a "close" flag, and its segment
// readout API (FPDFPath_CountSegments / FPDFPath_GetPathSegment /
// FPDFPathSegment_*) enumerates that list verbatim. A cubic Bezier
// curve therefore surfaces as a *triplet* of bezierto segments:
// first control point, second control point, endpoint.
//
// FPDFPath_GetBezierControlPoints (PDFium chromium/8066+) resolves
// which bezierto segment of a triplet is the endpoint: it succeeds
// only at an endpoint index and returns that curve's two control
// points. cpp_path_segments() uses it to attach cx1/cy1/cx2/cy2 to
// each curve's endpoint row (NA elsewhere), so callers don't have to
// re-derive triplet boundaries by counting.
//
// To minimize Rcpp call overhead for paths with many segments, the
// per-segment readout is batched: cpp_path_segments() returns a
// list of parallel vectors in one C++ call.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"

namespace {

inline FPDF_PAGEOBJECT paths_obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// [[Rcpp::export(name = "cpp_path_segment_count")]]
int cpp_path_segment_count(SEXP obj_ptr) {
  return FPDFPath_CountSegments(paths_obj_from_ptr(obj_ptr));
}

// [[Rcpp::export(name = "cpp_path_segments")]]
Rcpp::List cpp_path_segments(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = paths_obj_from_ptr(obj_ptr);
  int n = FPDFPath_CountSegments(obj);
  Rcpp::IntegerVector type(n);
  Rcpp::NumericVector x(n);
  Rcpp::NumericVector y(n);
  Rcpp::LogicalVector close(n);
  Rcpp::NumericVector cx1(n, NA_REAL);
  Rcpp::NumericVector cy1(n, NA_REAL);
  Rcpp::NumericVector cx2(n, NA_REAL);
  Rcpp::NumericVector cy2(n, NA_REAL);
  for (int i = 0; i < n; ++i) {
    FPDF_PATHSEGMENT seg = FPDFPath_GetPathSegment(obj, i);
    if (seg == nullptr) {
      Rcpp::stop("FPDFPath_GetPathSegment returned NULL at index %d", i);  // # nocov  // PDFium guarantees handles 0..N-1 are valid for the count it just reported
    }
    type[i] = FPDFPathSegment_GetType(seg);
    float xi = 0.0f, yi = 0.0f;
    FPDF_BOOL ok = FPDFPathSegment_GetPoint(seg, &xi, &yi);
    if (!ok) {
      Rcpp::stop("FPDFPathSegment_GetPoint failed at index %d", i);  // # nocov  // PDFium's GetPoint never fails on a valid segment handle
    }
    x[i] = static_cast<double>(xi);
    y[i] = static_cast<double>(yi);
    close[i] = (FPDFPathSegment_GetClose(seg) != 0);
    if (type[i] == FPDF_SEGMENT_BEZIERTO) {
      // Fails (leaving the NAs) for the two control-point rows of a
      // triplet; succeeds only at the curve's endpoint.
      FS_POINTF cp1;
      FS_POINTF cp2;
      if (FPDFPath_GetBezierControlPoints(obj, static_cast<size_t>(i),
                                          &cp1, &cp2)) {
        cx1[i] = static_cast<double>(cp1.x);
        cy1[i] = static_cast<double>(cp1.y);
        cx2[i] = static_cast<double>(cp2.x);
        cy2[i] = static_cast<double>(cp2.y);
      }
    }
  }
  return Rcpp::List::create(
    Rcpp::_["type"]  = type,
    Rcpp::_["x"]     = x,
    Rcpp::_["y"]     = y,
    Rcpp::_["close"] = close,
    Rcpp::_["cx1"]   = cx1,
    Rcpp::_["cy1"]   = cy1,
    Rcpp::_["cx2"]   = cx2,
    Rcpp::_["cy2"]   = cy2
  );
}
