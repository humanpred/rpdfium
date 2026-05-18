// pdfium R package — annotation enumeration on a page.
//
// PDFium models annotations as FPDF_ANNOTATION handles per page
// with a 29-entry subtype enum (FPDF_ANNOT_TEXT through
// FPDF_ANNOT_REDACT) plus FPDF_ANNOT_UNKNOWN. Each annotation
// carries a rectangle in PDF user space, a 32-bit flags bitmask
// (visible/invisible/print/locked/...), and an unbounded
// key/value dictionary; this wrapper exposes the structural
// scalars plus the two free-text string entries most annotation
// kinds carry: /Contents (the annotation body text) and /T
// (the title / author).
//
// Lifetime: each FPDF_ANNOTATION must be closed via
// FPDFPage_CloseAnnot when the caller is done with it. We open
// and close it inside the C++ wrapper for each row, so no
// PDFium-owned annotation handle leaves the R side.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "utf16.h"

namespace {

FPDF_PAGE page_from_ptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

std::string read_annot_string(FPDF_ANNOTATION annot, const char* key) {
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

// [[Rcpp::export(name = "cpp_annot_count")]]
int cpp_annot_count(SEXP page_ptr) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  int n = FPDFPage_GetAnnotCount(page);
  if (n < 0) {
    Rcpp::stop("FPDFPage_GetAnnotCount returned %d.", n);
  }
  return n;
}

// Helper: pull the four components of a single annotation color
// (FPDFANNOT_COLORTYPE_Color or _InteriorColor) into 0..1 doubles,
// or fill all four slots with NA_REAL when the annotation has no
// color set for that role.
//
// PDFium's FPDFAnnot_GetColor falls back to the appearance stream's
// color when /C (or /IC) is absent from the annotation dictionary,
// which makes "color was not specified" indistinguishable from
// "the appearance stream draws in black" at the API surface. We
// gate on FPDFAnnot_HasKey first so callers get NA when the PDF
// genuinely didn't set the color.
void read_annot_color(FPDF_ANNOTATION annot,
                      FPDFANNOT_COLORTYPE which,
                      double& r, double& g, double& b, double& a) {
  const char* key = (which == FPDFANNOT_COLORTYPE_InteriorColor)
                       ? "IC" : "C";
  if (!FPDFAnnot_HasKey(annot, key)) {
    r = g = b = a = NA_REAL;
    return;
  }
  unsigned int ur = 0, ug = 0, ub = 0, ua = 0;
  if (FPDFAnnot_GetColor(annot, which, &ur, &ug, &ub, &ua)) {
    r = ur / 255.0;
    g = ug / 255.0;
    b = ub / 255.0;
    a = ua / 255.0;
  } else {
    r = g = b = a = NA_REAL;
  }
}

// [[Rcpp::export(name = "cpp_annots_list")]]
Rcpp::List cpp_annots_list(SEXP page_ptr) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  int n = FPDFPage_GetAnnotCount(page);
  if (n < 0) n = 0;

  Rcpp::IntegerVector   subtype_code(n);
  Rcpp::IntegerVector   flags(n);
  Rcpp::NumericVector   left(n);
  Rcpp::NumericVector   bottom(n);
  Rcpp::NumericVector   right(n);
  Rcpp::NumericVector   top(n);
  Rcpp::CharacterVector contents(n);
  Rcpp::CharacterVector title(n);
  Rcpp::CharacterVector subject(n);
  Rcpp::NumericVector   color_r(n), color_g(n), color_b(n), color_a(n);
  Rcpp::NumericVector   interior_r(n), interior_g(n), interior_b(n),
                         interior_a(n);
  Rcpp::NumericVector   border_width(n);

  for (int i = 0; i < n; ++i) {
    FPDF_ANNOTATION annot = FPDFPage_GetAnnot(page, i);
    if (annot == nullptr) {
      subtype_code[i] = NA_INTEGER;
      flags[i]        = NA_INTEGER;
      left[i]         = NA_REAL;
      bottom[i]       = NA_REAL;
      right[i]        = NA_REAL;
      top[i]          = NA_REAL;
      contents[i]     = NA_STRING;
      title[i]        = NA_STRING;
      subject[i]      = NA_STRING;
      color_r[i] = color_g[i] = color_b[i] = color_a[i] = NA_REAL;
      interior_r[i] = interior_g[i] = interior_b[i] = interior_a[i] =
          NA_REAL;
      border_width[i] = NA_REAL;
      continue;
    }
    subtype_code[i] = static_cast<int>(FPDFAnnot_GetSubtype(annot));
    flags[i]        = FPDFAnnot_GetFlags(annot);
    FS_RECTF rect;
    if (FPDFAnnot_GetRect(annot, &rect)) {
      left[i]   = rect.left;
      bottom[i] = rect.bottom;
      right[i]  = rect.right;
      top[i]    = rect.top;
    } else {
      left[i] = bottom[i] = right[i] = top[i] = NA_REAL;
    }
    contents[i] = read_annot_string(annot, "Contents");
    title[i]    = read_annot_string(annot, "T");
    subject[i]  = read_annot_string(annot, "Subj");
    double r, g, b, a;
    read_annot_color(annot, FPDFANNOT_COLORTYPE_Color, r, g, b, a);
    color_r[i] = r; color_g[i] = g; color_b[i] = b; color_a[i] = a;
    read_annot_color(annot, FPDFANNOT_COLORTYPE_InteriorColor,
                     r, g, b, a);
    interior_r[i] = r; interior_g[i] = g;
    interior_b[i] = b; interior_a[i] = a;
    // FPDFAnnot_GetBorder is only meaningful for annotation types
    // that carry a /Border entry (line/square/circle/polygon/
    // polyline). PDFium returns false otherwise; surface NA in
    // that case.
    float hor_radius = 0.f, ver_radius = 0.f, bw = 0.f;
    if (FPDFAnnot_GetBorder(annot, &hor_radius, &ver_radius, &bw)) {
      border_width[i] = bw;
    } else {
      border_width[i] = NA_REAL;
    }
    FPDFPage_CloseAnnot(annot);
  }
  return Rcpp::List::create(
      Rcpp::_["subtype_code"]  = subtype_code,
      Rcpp::_["flags"]         = flags,
      Rcpp::_["bounds_left"]   = left,
      Rcpp::_["bounds_bottom"] = bottom,
      Rcpp::_["bounds_right"]  = right,
      Rcpp::_["bounds_top"]    = top,
      Rcpp::_["contents"]      = contents,
      Rcpp::_["title"]         = title,
      Rcpp::_["subject"]       = subject,
      Rcpp::_["color_red"]     = color_r,
      Rcpp::_["color_green"]   = color_g,
      Rcpp::_["color_blue"]    = color_b,
      Rcpp::_["color_alpha"]   = color_a,
      Rcpp::_["interior_red"]   = interior_r,
      Rcpp::_["interior_green"] = interior_g,
      Rcpp::_["interior_blue"]  = interior_b,
      Rcpp::_["interior_alpha"] = interior_a,
      Rcpp::_["border_width"]  = border_width);
}
