// pdfium R package — clip-path readout.
//
// A PDF clip path is the geometric region inside which a page
// object is allowed to draw. PDFium exposes it as an opaque
// FPDF_CLIPPATH attached to a page object, with its own
// hierarchy: a clip path contains one or more sub-paths, and each
// sub-path contains an ordered sequence of segments
// (moveto/lineto/bezierto), shaped exactly like the segments
// inside a regular FPDF_PAGEOBJECT path. Four public functions
// thread together the surface:
//
//   FPDFPageObj_GetClipPath(obj) -> FPDF_CLIPPATH (or NULL)
//   FPDFClipPath_CountPaths(clip) -> int
//   FPDFClipPath_CountPathSegments(clip, path_index) -> int
//   FPDFClipPath_GetPathSegment(clip, path_index, seg_index) -> FPDF_PATHSEGMENT
//
// The FPDF_CLIPPATH is part of its page-object: FPDFPageObj_GetClipPath
// returns the object's own clip path, which lives as long as the
// object. We wrap it in an externalptr without a finalizer and keep
// the object's externalptr in `prot`, so R's GC cannot reclaim the
// object's owners while any clip reference is live, and
// validate_handle() refuses the clip path once the object, or
// anything that owns it, is closed (ADR-029).

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_transformpage.h"
#include "fpdf_edit.h"
#include "handle_validation.h"

namespace {

FPDF_PAGEOBJECT obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

FPDF_CLIPPATH clip_from_ptr(SEXP clip_ptr) {
  // Clip paths belong to their page-object (no finalizer); prot pins
  // the object.
  return static_cast<FPDF_CLIPPATH>(
      pdfium_r::validate_handle(clip_ptr, "Clip-path",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// [[Rcpp::export(name = "cpp_obj_get_clip_path")]]
SEXP cpp_obj_get_clip_path(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  FPDF_CLIPPATH clip = FPDFPageObj_GetClipPath(obj);
  if (clip == nullptr) return R_NilValue;
  // No finalizer: the clip path is part of the object.
  return R_MakeExternalPtr(clip, R_NilValue, obj_ptr);
}

// [[Rcpp::export(name = "cpp_clip_path_count_paths")]]
int cpp_clip_path_count_paths(SEXP clip_ptr) {
  FPDF_CLIPPATH clip = clip_from_ptr(clip_ptr);
  // PDFium returns -1 when the clip path handle exists but has no
  // sub-paths attached (its CPDF_ClipPath has `!HasRef()`). Surface
  // that as 0 rather than an error so callers can treat it as a
  // degenerate "empty clip" - the R wrapper turns this into NULL
  // upstream in pdf_obj_clip_path() so users never see the empty
  // sentinel directly.
  int n = FPDFClipPath_CountPaths(clip);
  return n < 0 ? 0 : n;
}

// [[Rcpp::export(name = "cpp_clip_path_count_segments")]]
int cpp_clip_path_count_segments(SEXP clip_ptr, int path_index_zero) {
  FPDF_CLIPPATH clip = clip_from_ptr(clip_ptr);
  int n = FPDFClipPath_CountPathSegments(clip, path_index_zero);
  return n < 0 ? 0 : n;
}

// [[Rcpp::export(name = "cpp_clip_path_segments_df")]]
Rcpp::List cpp_clip_path_segments_df(SEXP clip_ptr) {
  FPDF_CLIPPATH clip = clip_from_ptr(clip_ptr);
  int n_paths = FPDFClipPath_CountPaths(clip);
  // # nocov start — the R wrapper (R/clip.R) calls
  // cpp_clip_path_count_paths() first and treats a 0/negative result
  // as "no clip path" so cpp_clip_path_segments_df() is never
  // entered with a negative-count clip. Belt-and-braces guard.
  if (n_paths < 0) {
    Rcpp::stop("FPDFClipPath_CountPaths returned %d.", n_paths);
  }
  // # nocov end
  // Two-pass collection: first count total segments across all
  // sub-paths so we can pre-allocate the output columns.
  int total = 0;
  for (int p = 0; p < n_paths; ++p) {
    int ns = FPDFClipPath_CountPathSegments(clip, p);
    if (ns < 0) continue;
    total += ns;
  }
  Rcpp::IntegerVector   path_index(total);
  Rcpp::IntegerVector   seg_index(total);
  Rcpp::IntegerVector   seg_type(total);
  Rcpp::NumericVector   x(total);
  Rcpp::NumericVector   y(total);
  Rcpp::LogicalVector   close_figure(total);

  int row = 0;
  for (int p = 0; p < n_paths; ++p) {
    int ns = FPDFClipPath_CountPathSegments(clip, p);
    if (ns < 0) continue;
    for (int s = 0; s < ns; ++s) {
      FPDF_PATHSEGMENT seg =
          FPDFClipPath_GetPathSegment(clip, p, s);
      // # nocov start — FPDFClipPath_GetPathSegment never returns
      // NULL for indices in [0, count); the NA fallback row is
      // defensive against a future PDFium contract change.
      if (seg == nullptr) {
        path_index[row]   = p + 1;
        seg_index[row]    = s + 1;
        seg_type[row]     = NA_INTEGER;
        x[row]            = NA_REAL;
        y[row]            = NA_REAL;
        close_figure[row] = NA_LOGICAL;
        ++row;
        continue;
      }
      // # nocov end
      float xf = 0.0f;
      float yf = 0.0f;
      FPDF_BOOL ok = FPDFPathSegment_GetPoint(seg, &xf, &yf);
      int t = FPDFPathSegment_GetType(seg);
      FPDF_BOOL closed = FPDFPathSegment_GetClose(seg);
      path_index[row]   = p + 1;
      seg_index[row]    = s + 1;
      seg_type[row]     = t;
      x[row]            = ok ? static_cast<double>(xf) : NA_REAL;
      y[row]            = ok ? static_cast<double>(yf) : NA_REAL;
      close_figure[row] = static_cast<bool>(closed);
      ++row;
    }
  }
  return Rcpp::List::create(
      Rcpp::_["path_index"]   = path_index,
      Rcpp::_["seg_index"]    = seg_index,
      Rcpp::_["seg_type"]     = seg_type,
      Rcpp::_["x"]            = x,
      Rcpp::_["y"]            = y,
      Rcpp::_["close_figure"] = close_figure);
}
