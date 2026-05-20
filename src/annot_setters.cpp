// pdfium R package — annotation property setters (Phase 6).
//
// Per-attribute setters for `pdfium_annot` handles. Each shim
// takes the annot externalptr and the new value(s), validates the
// pointer via the shared handle_validation.h helper (parent page
// must still be alive, ADR-020 §4), and calls the matching
// FPDFAnnot_Set* symbol.
//
// Annotation creation (cpp_annot_new) and removal (cpp_annot_delete)
// live in annot_handles.cpp alongside cpp_annot_get because they
// share the finalize_annot helper. The setters in this file don't
// allocate or release annot handles; they only mutate.

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "handle_validation.h"
#include "utf16.h"

namespace {

inline FPDF_ANNOTATION annot_from_ptr(SEXP annot_ptr) {
  return static_cast<FPDF_ANNOTATION>(
      pdfium_r::validate_handle(annot_ptr, "Annotation",
                                  /*require_prot_alive=*/true));
}

inline unsigned int rgba_channel(double v, const char* what) {
  if (Rcpp::NumericVector::is_na(v)) {
    Rcpp::stop("RGBA channel `%s` must not be NA.", what);
  }
  if (v < 0.0 || v > 255.0) {
    Rcpp::stop("RGBA channel `%s` must be in [0, 255]; got %g.",
                what, v);
  }
  return static_cast<unsigned int>(v + 0.5);
}

}  // namespace

// [[Rcpp::export(name = "cpp_annot_set_rect")]]
bool cpp_annot_set_rect(SEXP annot_ptr,
                          double left, double bottom,
                          double right, double top) {
  FPDF_ANNOTATION a = annot_from_ptr(annot_ptr);
  FS_RECTF r;
  r.left   = static_cast<float>(left);
  r.bottom = static_cast<float>(bottom);
  r.right  = static_cast<float>(right);
  r.top    = static_cast<float>(top);
  return FPDFAnnot_SetRect(a, &r) != 0;
}

// FPDFANNOT_COLORTYPE_Color = 0, _InteriorColor = 1.
// [[Rcpp::export(name = "cpp_annot_set_color")]]
bool cpp_annot_set_color(SEXP annot_ptr, int color_type,
                          double r, double g, double b, double a_) {
  FPDF_ANNOTATION a = annot_from_ptr(annot_ptr);
  return FPDFAnnot_SetColor(
      a, static_cast<FPDFANNOT_COLORTYPE>(color_type),
      rgba_channel(r, "red"), rgba_channel(g, "green"),
      rgba_channel(b, "blue"), rgba_channel(a_, "alpha")) != 0;
}

// [[Rcpp::export(name = "cpp_annot_set_flags")]]
bool cpp_annot_set_flags(SEXP annot_ptr, int flags) {
  return FPDFAnnot_SetFlags(annot_from_ptr(annot_ptr), flags) != 0;
}

// FPDFAnnot_SetStringValue takes a NUL-terminated UTF-16LE
// FPDF_WIDESTRING. The R wrapper passes UTF-8 in; we re-encode
// here so callers don't have to know about the wire format.
// [[Rcpp::export(name = "cpp_annot_set_string_value")]]
bool cpp_annot_set_string_value(SEXP annot_ptr,
                                  std::string key,
                                  std::string value_utf8) {
  FPDF_ANNOTATION a = annot_from_ptr(annot_ptr);
  std::vector<unsigned short> utf16 =
      pdfium_r::utf8_to_utf16le_nul(value_utf8);
  return FPDFAnnot_SetStringValue(
      a, key.c_str(),
      reinterpret_cast<FPDF_WIDESTRING>(utf16.data())) != 0;
}

// Append a quad to an annotation's /QuadPoints array. PDFium also
// has FPDFAnnot_SetAttachmentPoints(annot, index, quad) for
// rewriting individual quads but we only expose the append form in
// Phase 6 (the read-side surface returns the whole quad list at
// once, and the natural authoring model is "build the list from
// scratch").
// [[Rcpp::export(name = "cpp_annot_append_quad")]]
bool cpp_annot_append_quad(SEXP annot_ptr,
                            double x1, double y1,
                            double x2, double y2,
                            double x3, double y3,
                            double x4, double y4) {
  FPDF_ANNOTATION a = annot_from_ptr(annot_ptr);
  FS_QUADPOINTSF q;
  q.x1 = static_cast<float>(x1);
  q.y1 = static_cast<float>(y1);
  q.x2 = static_cast<float>(x2);
  q.y2 = static_cast<float>(y2);
  q.x3 = static_cast<float>(x3);
  q.y3 = static_cast<float>(y3);
  q.x4 = static_cast<float>(x4);
  q.y4 = static_cast<float>(y4);
  return FPDFAnnot_AppendAttachmentPoints(a, &q) != 0;
}
