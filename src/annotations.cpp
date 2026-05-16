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
    FPDFPage_CloseAnnot(annot);
  }
  return Rcpp::List::create(
      Rcpp::_["subtype_code"] = subtype_code,
      Rcpp::_["flags"]        = flags,
      Rcpp::_["bounds_left"]   = left,
      Rcpp::_["bounds_bottom"] = bottom,
      Rcpp::_["bounds_right"]  = right,
      Rcpp::_["bounds_top"]    = top,
      Rcpp::_["contents"]     = contents,
      Rcpp::_["title"]        = title);
}
