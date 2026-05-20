// pdfium R package — per-annotation handle shims.
//
// Companion to src/annotations.cpp's bulk reader. Where the bulk
// reader returns one big table for all annotations on a page, this
// file returns ONE annotation handle at a time. The handle is an R
// externalptr with a finalizer that calls FPDFPage_CloseAnnot, so
// R's GC reclaims annotation memory deterministically when the
// `pdfium_annot` is no longer reachable.
//
// Per-attribute getters live here too. Each is a single PDFium
// call; the R-side `pdf_annot_*` functions are thin wrappers.
// Inputs are always the bare externalptr; the R layer validates
// shape via checkmate before calling.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_formfill.h"
#include "utf16.h"

namespace {

FPDF_ANNOTATION annot_from_ptr(SEXP annot_ptr) {
  if (TYPEOF(annot_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the annotation.");
  }
  FPDF_ANNOTATION annot =
      static_cast<FPDF_ANNOTATION>(R_ExternalPtrAddr(annot_ptr));
  if (annot == nullptr) {
    Rcpp::stop("Annotation handle is NULL (closed?).");
  }
  return annot;
}

FPDF_PAGE page_from_ptr_local(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

void finalize_annot(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) return;
  FPDF_ANNOTATION a =
      static_cast<FPDF_ANNOTATION>(R_ExternalPtrAddr(ptr));
  if (a != nullptr) {
    FPDFPage_CloseAnnot(a);
    R_ClearExternalPtr(ptr);
  }
}

std::string read_annot_string_local(FPDF_ANNOTATION annot, const char* key) {
  unsigned long needed = FPDFAnnot_GetStringValue(annot, key, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDFAnnot_GetStringValue(annot, key,
                           reinterpret_cast<FPDF_WCHAR*>(buf.data()),
                           needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

}  // namespace

// [[Rcpp::export(name = "cpp_annot_get")]]
SEXP cpp_annot_get(SEXP page_ptr, int index_zero_based) {
  FPDF_PAGE page = page_from_ptr_local(page_ptr);
  FPDF_ANNOTATION a = FPDFPage_GetAnnot(page, index_zero_based);
  if (a == nullptr) {
    Rcpp::stop("FPDFPage_GetAnnot(%d) returned NULL.",
               index_zero_based);
  }
  // Pin the parent page in the externalptr's `prot` slot so the
  // page can't be GC'd before this annot handle. Matches the
  // pattern used by pdfium_obj.
  SEXP ptr = PROTECT(R_MakeExternalPtr(a, R_NilValue, page_ptr));
  R_RegisterCFinalizerEx(ptr, finalize_annot,
                         static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ptr;
}

// [[Rcpp::export(name = "cpp_annot_subtype_code")]]
int cpp_annot_subtype_code(SEXP annot_ptr) {
  return static_cast<int>(FPDFAnnot_GetSubtype(annot_from_ptr(annot_ptr)));
}

// [[Rcpp::export(name = "cpp_annot_flags")]]
int cpp_annot_flags(SEXP annot_ptr) {
  return FPDFAnnot_GetFlags(annot_from_ptr(annot_ptr));
}

// [[Rcpp::export(name = "cpp_annot_bounds")]]
Rcpp::NumericVector cpp_annot_bounds(SEXP annot_ptr) {
  FS_RECTF r;
  Rcpp::NumericVector out =
      Rcpp::NumericVector::create(NA_REAL, NA_REAL, NA_REAL, NA_REAL);
  out.attr("names") = Rcpp::CharacterVector::create(
      "bounds_left", "bounds_bottom", "bounds_right", "bounds_top");
  if (FPDFAnnot_GetRect(annot_from_ptr(annot_ptr), &r)) {
    out[0] = r.left;
    out[1] = r.bottom;
    out[2] = r.right;
    out[3] = r.top;
  }
  return out;
}

// [[Rcpp::export(name = "cpp_annot_string_value")]]
std::string cpp_annot_string_value(SEXP annot_ptr, std::string key) {
  return read_annot_string_local(annot_from_ptr(annot_ptr), key.c_str());
}

// [[Rcpp::export(name = "cpp_annot_color")]]
Rcpp::NumericVector cpp_annot_color(SEXP annot_ptr,
                                    bool interior) {
  unsigned int r = 0, g = 0, b = 0, a = 255;
  Rcpp::NumericVector out =
      Rcpp::NumericVector::create(NA_REAL, NA_REAL, NA_REAL, NA_REAL);
  out.attr("names") = Rcpp::CharacterVector::create(
      "red", "green", "blue", "alpha");
  FPDFANNOT_COLORTYPE ct = interior ? FPDFANNOT_COLORTYPE_InteriorColor
                                    : FPDFANNOT_COLORTYPE_Color;
  if (FPDFAnnot_GetColor(annot_from_ptr(annot_ptr), ct,
                         &r, &g, &b, &a)) {
    out[0] = r / 255.0;
    out[1] = g / 255.0;
    out[2] = b / 255.0;
    out[3] = a / 255.0;
  }
  return out;
}

// [[Rcpp::export(name = "cpp_annot_border")]]
double cpp_annot_border(SEXP annot_ptr) {
  float h = 0.f, v = 0.f, w = 0.f;
  if (!FPDFAnnot_GetBorder(annot_from_ptr(annot_ptr), &h, &v, &w)) {
    return NA_REAL;
  }
  return w;
}

// [[Rcpp::export(name = "cpp_annot_font_size")]]
double cpp_annot_font_size(SEXP annot_ptr, SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) return NA_REAL;
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) return NA_REAL;
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) return NA_REAL;
  float sz = 0.f;
  bool ok = FPDFAnnot_GetFontSize(form, annot_from_ptr(annot_ptr), &sz);
  FPDFDOC_ExitFormFillEnvironment(form);
  return ok ? sz : NA_REAL;
}

// [[Rcpp::export(name = "cpp_annot_font_color")]]
Rcpp::NumericVector cpp_annot_font_color(SEXP annot_ptr, SEXP doc_ptr) {
  Rcpp::NumericVector out =
      Rcpp::NumericVector::create(NA_REAL, NA_REAL, NA_REAL);
  out.attr("names") =
      Rcpp::CharacterVector::create("red", "green", "blue");
  if (TYPEOF(doc_ptr) != EXTPTRSXP) return out;
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) return out;
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) return out;
  unsigned int r = 0, g = 0, b = 0;
  if (FPDFAnnot_GetFontColor(form, annot_from_ptr(annot_ptr),
                             &r, &g, &b)) {
    out[0] = r / 255.0;
    out[1] = g / 255.0;
    out[2] = b / 255.0;
  }
  FPDFDOC_ExitFormFillEnvironment(form);
  return out;
}

// [[Rcpp::export(name = "cpp_annot_has_attachment_points")]]
bool cpp_annot_has_attachment_points(SEXP annot_ptr) {
  return FPDFAnnot_HasAttachmentPoints(annot_from_ptr(annot_ptr));
}
