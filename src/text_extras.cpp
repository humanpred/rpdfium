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
#include "handle_validation.h"

namespace {

inline FPDF_PAGEOBJECT te_obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

inline FPDF_PAGE te_page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

}  // namespace

// [[Rcpp::export(name = "cpp_text_render_mode")]]
int cpp_text_render_mode(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = te_obj_from_ptr(obj_ptr);
  // Returns -1 (FPDF_TEXTRENDERMODE_UNKNOWN) on failure, 0..7 on
  // success. The R wrapper maps to a string.
  return static_cast<int>(FPDFTextObj_GetTextRenderMode(obj));
}

// Per-character fill/stroke colors and the corresponding text-index
// (position in the page's text stream as returned by FPDFText_GetText;
// generated / formatting chars return -1 here).
// [[Rcpp::export(name = "cpp_page_text_colors")]]
Rcpp::List cpp_page_text_colors(SEXP page_ptr) {
  FPDF_PAGE page = te_page_from_ptr(page_ptr);

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

// FPDFText_GetTextObject — direct accessor that returns the page
// object owning a given char on the text-page. Returns a list of
// (ptr externalptr, obj_index integer) so the R wrapper can build a
// pdfium_obj. Iterates over the page-object table to discover the
// obj_index because FPDFText_GetTextObject returns a borrowed
// pointer without an index hint.
//
// Returns ptr = R_NilValue and obj_index = NA_integer_ when the
// char has no associated text-object (e.g. PDFium-inserted
// whitespace).
// [[Rcpp::export(name = "cpp_text_obj_at_char")]]
Rcpp::List cpp_text_obj_at_char(SEXP page_ptr, int char_index) {
  FPDF_PAGE page = static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) {
    // # nocov start — FPDFText_LoadPage returns NULL only on OOM;
    // chromium/7202 succeeds in the test sizes we exercise.
    Rcpp::stop("FPDFText_LoadPage returned NULL.");
    // # nocov end
  }
  FPDF_PAGEOBJECT obj = FPDFText_GetTextObject(tp, char_index);
  FPDFText_ClosePage(tp);

  if (obj == nullptr) {
    return Rcpp::List::create(
      Rcpp::_["ptr"]       = R_NilValue,
      Rcpp::_["obj_index"] = NA_INTEGER);
  }

  // Locate obj_index by scanning page objects for pointer equality.
  // PDFium returns the same handle on every call for a given object
  // until the page closes, so a pointer compare is the correct
  // identity check.
  int n = FPDFPage_CountObjects(page);
  int found = -1;
  for (int i = 0; i < n; ++i) {
    if (FPDFPage_GetObject(page, i) == obj) {
      found = i;
      break;
    }
  }
  if (found < 0) {
    // # nocov start — FPDFText_GetTextObject returns an object that
    // must exist in the page's content stream; FPDFPage_GetObject
    // enumerates that same stream. A mismatch indicates PDFium-
    // internal inconsistency.
    return Rcpp::List::create(
      Rcpp::_["ptr"]       = R_NilValue,
      Rcpp::_["obj_index"] = NA_INTEGER);
    // # nocov end
  }

  // No finalizer: the page owns the page-object. prot pins the page
  // so the parent-liveness check in downstream cpp shims works.
  SEXP ext = PROTECT(R_MakeExternalPtr(obj, R_NilValue, page_ptr));
  Rcpp::List out = Rcpp::List::create(
    Rcpp::_["ptr"]       = ext,
    Rcpp::_["obj_index"] = found + 1);
  UNPROTECT(1);
  return out;
}
