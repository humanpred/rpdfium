// pdfium R package — page-object styling setters (Phase 3).
//
// Each shim wraps one FPDFPageObj_Set* or related PDFium setter.
// The R wrappers in `R/obj_setters.R` validate inputs, call here,
// and mark the parent page dirty so pdf_save() / pdf_render_*()
// see the change.
//
// Lifetime: page-object externalptrs are page-owned (no finalizer);
// the obj_from_ptr helper requires the parent page externalptr in
// the prot slot to still be alive — closing the parent page after
// taking an obj reference raises a clean R error instead of
// dereferencing freed memory (ADR-020 §4).

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"
#include "utf16.h"

namespace {

inline FPDF_PAGEOBJECT obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

inline FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

// Clamp + cast a 0-255 RGBA component R-side normalises into.
// Out-of-range values land here when the R wrapper has a bug;
// PDFium tolerates >255 by overflowing, so we'd rather error.
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

// [[Rcpp::export(name = "cpp_obj_set_matrix")]]
bool cpp_obj_set_matrix(SEXP obj_ptr, Rcpp::NumericVector m) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  if (m.size() != 6) {
    Rcpp::stop("Matrix must be a length-6 vector (a, b, c, d, e, f).");
  }
  FS_MATRIX mat;
  mat.a = static_cast<float>(m[0]);
  mat.b = static_cast<float>(m[1]);
  mat.c = static_cast<float>(m[2]);
  mat.d = static_cast<float>(m[3]);
  mat.e = static_cast<float>(m[4]);
  mat.f = static_cast<float>(m[5]);
  return FPDFPageObj_SetMatrix(obj, &mat) != 0;
}

// [[Rcpp::export(name = "cpp_obj_set_active")]]
bool cpp_obj_set_active(SEXP obj_ptr, bool active) {
  return FPDFPageObj_SetIsActive(obj_from_ptr(obj_ptr),
                                  active ? 1 : 0) != 0;
}

// [[Rcpp::export(name = "cpp_obj_set_blend_mode")]]
void cpp_obj_set_blend_mode(SEXP obj_ptr, std::string mode) {
  // FPDFPageObj_SetBlendMode is a void-returning setter; PDFium
  // silently accepts unknown blend-mode strings and writes them
  // verbatim. The R wrapper validates the name against the spec
  // table before reaching here.
  FPDFPageObj_SetBlendMode(obj_from_ptr(obj_ptr), mode.c_str());
}

// [[Rcpp::export(name = "cpp_obj_set_stroke_color")]]
bool cpp_obj_set_stroke_color(SEXP obj_ptr, double r, double g,
                                double b, double a) {
  return FPDFPageObj_SetStrokeColor(
      obj_from_ptr(obj_ptr),
      rgba_channel(r, "red"), rgba_channel(g, "green"),
      rgba_channel(b, "blue"), rgba_channel(a, "alpha")) != 0;
}

// [[Rcpp::export(name = "cpp_obj_set_fill_color")]]
bool cpp_obj_set_fill_color(SEXP obj_ptr, double r, double g,
                              double b, double a) {
  return FPDFPageObj_SetFillColor(
      obj_from_ptr(obj_ptr),
      rgba_channel(r, "red"), rgba_channel(g, "green"),
      rgba_channel(b, "blue"), rgba_channel(a, "alpha")) != 0;
}

// [[Rcpp::export(name = "cpp_obj_set_stroke_width")]]
bool cpp_obj_set_stroke_width(SEXP obj_ptr, double w) {
  return FPDFPageObj_SetStrokeWidth(obj_from_ptr(obj_ptr),
                                      static_cast<float>(w)) != 0;
}

// [[Rcpp::export(name = "cpp_obj_set_line_cap")]]
bool cpp_obj_set_line_cap(SEXP obj_ptr, int cap) {
  return FPDFPageObj_SetLineCap(obj_from_ptr(obj_ptr), cap) != 0;
}

// [[Rcpp::export(name = "cpp_obj_set_line_join")]]
bool cpp_obj_set_line_join(SEXP obj_ptr, int join) {
  return FPDFPageObj_SetLineJoin(obj_from_ptr(obj_ptr), join) != 0;
}

// [[Rcpp::export(name = "cpp_obj_set_dash")]]
bool cpp_obj_set_dash(SEXP obj_ptr, Rcpp::NumericVector array,
                        double phase) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  size_t n = static_cast<size_t>(array.size());
  std::vector<float> buf(n);
  for (size_t i = 0; i < n; ++i) {
    if (Rcpp::NumericVector::is_na(array[i])) {
      Rcpp::stop("Dash array must not contain NA.");
    }
    buf[i] = static_cast<float>(array[i]);
  }
  // FPDFPageObj_SetDashArray takes (obj, array, count, phase) and
  // handles the n=0 case (clears the dash). Pass nullptr when n=0
  // so we don't trip a vector-data-on-empty-vector UB.
  const float* data = n == 0 ? nullptr : buf.data();
  return FPDFPageObj_SetDashArray(obj, data, n,
                                    static_cast<float>(phase)) != 0;
}

// [[Rcpp::export(name = "cpp_path_set_draw_mode")]]
bool cpp_path_set_draw_mode(SEXP obj_ptr, int fillmode, bool stroke) {
  return FPDFPath_SetDrawMode(obj_from_ptr(obj_ptr), fillmode,
                                stroke ? 1 : 0) != 0;
}

// [[Rcpp::export(name = "cpp_text_set_content")]]
bool cpp_text_set_content(SEXP obj_ptr, std::string text_utf8) {
  // FPDFText_SetText takes UTF-16LE NUL-terminated.
  std::vector<unsigned short> utf16 =
      pdfium_r::utf8_to_utf16le_nul(text_utf8);
  return FPDFText_SetText(
      obj_from_ptr(obj_ptr),
      reinterpret_cast<FPDF_WIDESTRING>(utf16.data())) != 0;
}

// [[Rcpp::export(name = "cpp_text_set_render_mode")]]
bool cpp_text_set_render_mode(SEXP obj_ptr, int mode) {
  // FPDFTextObj_SetTextRenderMode takes the enum value directly.
  // Valid: 0..7 (Fill, Stroke, FillStroke, Invisible, FillClip,
  // StrokeClip, FillStrokeClip, Clip). R wrapper validates.
  return FPDFTextObj_SetTextRenderMode(
      obj_from_ptr(obj_ptr),
      static_cast<FPDF_TEXT_RENDERMODE>(mode)) != 0;
}

// Marks ---------------------------------------------------------------

// Add a content mark with the given name. Returns the new mark's
// index (0-based) for the R wrapper to translate to 1-based; -1 on
// failure (FPDFPageObj_AddMark itself returns the mark handle, not
// an index, so we count marks afterwards to find ours).
// [[Rcpp::export(name = "cpp_obj_add_mark")]]
int cpp_obj_add_mark(SEXP obj_ptr, std::string name) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  FPDF_PAGEOBJECTMARK mark = FPDFPageObj_AddMark(obj, name.c_str());
  if (mark == nullptr) return -1;
  // The new mark sits at the end (PDFium appends). Return the
  // 0-based final index.
  int n = FPDFPageObj_CountMarks(obj);
  if (n <= 0) return -1;
  return n - 1;
}

// Remove a mark by 0-based index.
// [[Rcpp::export(name = "cpp_obj_remove_mark")]]
bool cpp_obj_remove_mark(SEXP obj_ptr, int mark_index_zero) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  FPDF_PAGEOBJECTMARK mark = FPDFPageObj_GetMark(obj, mark_index_zero);
  if (mark == nullptr) {
    Rcpp::stop("No content mark at index %d.", mark_index_zero);
  }
  return FPDFPageObj_RemoveMark(obj, mark) != 0;
}

// Set an integer parameter on an existing mark. doc_ptr is needed
// because PDFium's mark-param setter requires the doc for internal
// validation.
// [[Rcpp::export(name = "cpp_obj_mark_set_int_param")]]
bool cpp_obj_mark_set_int_param(SEXP doc_ptr, SEXP obj_ptr,
                                  int mark_index_zero,
                                  std::string key, int value) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  FPDF_PAGEOBJECTMARK mark = FPDFPageObj_GetMark(obj, mark_index_zero);
  if (mark == nullptr) {
    Rcpp::stop("No content mark at index %d.", mark_index_zero);
  }
  return FPDFPageObjMark_SetIntParam(doc, obj, mark,
                                       key.c_str(), value) != 0;
}

// Set a string parameter on an existing mark.
// [[Rcpp::export(name = "cpp_obj_mark_set_string_param")]]
bool cpp_obj_mark_set_string_param(SEXP doc_ptr, SEXP obj_ptr,
                                     int mark_index_zero,
                                     std::string key,
                                     std::string value) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  FPDF_PAGEOBJECTMARK mark = FPDFPageObj_GetMark(obj, mark_index_zero);
  if (mark == nullptr) {
    Rcpp::stop("No content mark at index %d.", mark_index_zero);
  }
  return FPDFPageObjMark_SetStringParam(doc, obj, mark,
                                         key.c_str(),
                                         value.c_str()) != 0;
}
