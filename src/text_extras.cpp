// pdfium R package — text appearance / render-mode extras.
//
// Adds to the text read surface:
//   FPDFTextObj_GetTextRenderMode -> pdf_text_render_mode(obj)
//   FPDFText_GetFillColor / GetStrokeColor / GetFontInfo
//     + FPDFText_GetTextIndexFromCharIndex
//                                  -> pdf_text_colors(page)
//
// The render-mode getter is per-text-object (FPDF_PAGEOBJECT). The
// colour and text-index getters operate against an FPDF_TEXTPAGE
// loaded from the page; we batch them into a single doc-style
// readout that returns parallel vectors over the page's character
// stream, so callers can join the result to pdf_text_chars() on
// char_index.

#include <Rcpp.h>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "fpdf_text.h"
#include "fpdf_searchex.h"

// [[Rcpp::export(name = "cpp_text_render_mode")]]
int cpp_text_render_mode(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGEOBJECT obj =
      static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) Rcpp::stop("Page-object handle is closed.");
  // Returns -1 (FPDF_TEXTRENDERMODE_UNKNOWN) on failure, 0..7 on
  // success. The R wrapper maps to a string.
  return static_cast<int>(FPDFTextObj_GetTextRenderMode(obj));
}

// Per-character fill/stroke colors and the corresponding text-index
// (position in the page's text stream as returned by FPDFText_GetText;
// generated / formatting chars return -1 here).
// [[Rcpp::export(name = "cpp_page_text_colors")]]
Rcpp::List cpp_page_text_colors(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");

  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");

  int n = FPDFText_CountChars(tp);
  if (n < 0) n = 0;
  Rcpp::IntegerVector text_index(n);
  Rcpp::IntegerVector fr(n), fg(n), fb(n), fa(n);
  Rcpp::IntegerVector sr(n), sg(n), sb(n), sa(n);
  for (int i = 0; i < n; ++i) {
    int ti = FPDFText_GetTextIndexFromCharIndex(tp, i);
    text_index[i] = (ti < 0) ? NA_INTEGER : ti;

    unsigned int r = 0, g = 0, b = 0, a = 0;
    if (FPDFText_GetFillColor(tp, i, &r, &g, &b, &a)) {
      fr[i] = static_cast<int>(r);
      fg[i] = static_cast<int>(g);
      fb[i] = static_cast<int>(b);
      fa[i] = static_cast<int>(a);
    } else {
      fr[i] = fg[i] = fb[i] = fa[i] = NA_INTEGER;
    }
    r = g = b = a = 0;
    if (FPDFText_GetStrokeColor(tp, i, &r, &g, &b, &a)) {
      sr[i] = static_cast<int>(r);
      sg[i] = static_cast<int>(g);
      sb[i] = static_cast<int>(b);
      sa[i] = static_cast<int>(a);
    } else {
      sr[i] = sg[i] = sb[i] = sa[i] = NA_INTEGER;
    }
  }
  FPDFText_ClosePage(tp);

  return Rcpp::List::create(
    Rcpp::_["text_index"]    = text_index,
    Rcpp::_["fill_red"]      = fr,
    Rcpp::_["fill_green"]    = fg,
    Rcpp::_["fill_blue"]     = fb,
    Rcpp::_["fill_alpha"]    = fa,
    Rcpp::_["stroke_red"]    = sr,
    Rcpp::_["stroke_green"]  = sg,
    Rcpp::_["stroke_blue"]   = sb,
    Rcpp::_["stroke_alpha"]  = sa
  );
}
