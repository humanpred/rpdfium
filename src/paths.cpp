// pdfium R package — path-segment readout.
//
// PDFium's segment readout API exposes the endpoint of each segment
// plus its segment type (moveto/lineto/bezierto) and a "close" flag.
// Critically, the readout API does NOT expose the two Bezier control
// points of a FPDF_SEGMENT_BEZIERTO segment - only the endpoint.
// Recovering control points requires content-stream parsing and is
// deferred to a later phase (see docs/pdfium-api-review.md).
//
// To minimize Rcpp call overhead for paths with many segments, the
// per-segment readout is batched: cpp_path_segments() returns a
// list of four parallel vectors (type, x, y, close) in one C++ call.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"

// [[Rcpp::export(name = "cpp_path_segment_count")]]
int cpp_path_segment_count(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGEOBJECT obj = static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) {
    Rcpp::stop("Page-object handle is closed.");
  }
  return FPDFPath_CountSegments(obj);
}

// [[Rcpp::export(name = "cpp_path_segments")]]
Rcpp::List cpp_path_segments(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGEOBJECT obj = static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) {
    Rcpp::stop("Page-object handle is closed.");
  }
  int n = FPDFPath_CountSegments(obj);
  Rcpp::IntegerVector type(n);
  Rcpp::NumericVector x(n);
  Rcpp::NumericVector y(n);
  Rcpp::LogicalVector close(n);
  for (int i = 0; i < n; ++i) {
    FPDF_PATHSEGMENT seg = FPDFPath_GetPathSegment(obj, i);
    if (seg == nullptr) {
      Rcpp::stop("FPDFPath_GetPathSegment returned NULL at index %d", i);
    }
    type[i] = FPDFPathSegment_GetType(seg);
    float xi = 0.0f, yi = 0.0f;
    FPDF_BOOL ok = FPDFPathSegment_GetPoint(seg, &xi, &yi);
    if (!ok) {
      Rcpp::stop("FPDFPathSegment_GetPoint failed at index %d", i);
    }
    x[i] = static_cast<double>(xi);
    y[i] = static_cast<double>(yi);
    close[i] = (FPDFPathSegment_GetClose(seg) != 0);
  }
  return Rcpp::List::create(
    Rcpp::_["type"]  = type,
    Rcpp::_["x"]     = x,
    Rcpp::_["y"]     = y,
    Rcpp::_["close"] = close
  );
}
