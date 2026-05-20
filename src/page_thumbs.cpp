// pdfium R package — page-level thumbnail and auto-detected
// web-link readouts.
//
// FPDFPage_GetRawThumbnailData       -> raw bytes of the embedded
//                                       /Thumb stream, with filter
//                                       (e.g. /FlateDecode) intact.
// FPDFPage_GetDecodedThumbnailData   -> decoded bitmap bytes.
// FPDFPage_GetThumbnailAsBitmap      -> not exposed: we already
//                                       return decoded bytes; the
//                                       FPDF_BITMAP wrapping is
//                                       redundant for the R use case.
//
// FPDFLink_LoadWebLinks + GetURL / GetTextRange / CountRects /
// GetRect / CloseWebLinks            -> auto-detected URL spans in
//                                       the page's extracted text
//                                       (no link annotation needed).

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_text.h"
#include "fpdf_thumbnail.h"
#include "utf16.h"

using pdfium_r::utf16le_to_utf8;

namespace {

FPDF_PAGE thumb_page_from_ptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

}  // namespace

// [[Rcpp::export(name = "cpp_page_thumbnail_raw")]]
Rcpp::RawVector cpp_page_thumbnail_raw(SEXP page_ptr) {
  FPDF_PAGE page = thumb_page_from_ptr(page_ptr);
  unsigned long need = FPDFPage_GetRawThumbnailData(page, nullptr, 0);
  if (need == 0) return Rcpp::RawVector(0);
  Rcpp::RawVector out(static_cast<R_xlen_t>(need));
  FPDFPage_GetRawThumbnailData(page,
                               reinterpret_cast<void*>(RAW(out)), need);
  return out;
}

// [[Rcpp::export(name = "cpp_page_thumbnail_decoded")]]
Rcpp::RawVector cpp_page_thumbnail_decoded(SEXP page_ptr) {
  FPDF_PAGE page = thumb_page_from_ptr(page_ptr);
  unsigned long need = FPDFPage_GetDecodedThumbnailData(page, nullptr, 0);
  if (need == 0) return Rcpp::RawVector(0);
  Rcpp::RawVector out(static_cast<R_xlen_t>(need));
  FPDFPage_GetDecodedThumbnailData(page,
                                    reinterpret_cast<void*>(RAW(out)),
                                    need);
  return out;
}

// PDFium's web-link detector finds URLs (http://..., https://...,
// www., mailto:...) within the page's extracted text and returns
// their start/end char indices plus per-line rectangles. Each
// detected link produces one row here; the rect list (which can
// span multiple lines) is collapsed to the axis-aligned union.
// [[Rcpp::export(name = "cpp_page_weblinks")]]
Rcpp::List cpp_page_weblinks(SEXP page_ptr) {
  FPDF_PAGE page = thumb_page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");

  FPDF_PAGELINK lp = FPDFLink_LoadWebLinks(tp);
  if (lp == nullptr) {
    FPDFText_ClosePage(tp);
    return Rcpp::List::create(
      Rcpp::_["url"]        = Rcpp::CharacterVector(0),
      Rcpp::_["start_char"] = Rcpp::IntegerVector(0),
      Rcpp::_["char_count"] = Rcpp::IntegerVector(0),
      Rcpp::_["left"]       = Rcpp::NumericVector(0),
      Rcpp::_["bottom"]     = Rcpp::NumericVector(0),
      Rcpp::_["right"]      = Rcpp::NumericVector(0),
      Rcpp::_["top"]        = Rcpp::NumericVector(0)
    );
  }
  int n = FPDFLink_CountWebLinks(lp);
  if (n < 0) n = 0;
  Rcpp::CharacterVector url(n);
  Rcpp::IntegerVector start_char(n), char_count(n);
  Rcpp::NumericVector left(n), bottom(n), right(n), top(n);

  for (int i = 0; i < n; ++i) {
    // URL: two-pass. FPDFLink_GetURL returns 16-bit code-unit count
    // INCLUDING the trailing NUL.
    int need = FPDFLink_GetURL(lp, i, nullptr, 0);
    if (need > 1) {
      std::vector<unsigned short> buf(static_cast<size_t>(need));
      FPDFLink_GetURL(lp, i, buf.data(), need);
      std::string utf8 = utf16le_to_utf8(buf.data(),
                                          static_cast<size_t>(need) - 1);
      url[i] = Rf_mkCharLenCE(utf8.data(),
                              static_cast<int>(utf8.size()), CE_UTF8);
    } else {
      url[i] = NA_STRING;
    }
    int sc = 0, cc = 0;
    if (FPDFLink_GetTextRange(lp, i, &sc, &cc)) {
      start_char[i] = sc;
      char_count[i] = cc;
    } else {
      start_char[i] = NA_INTEGER;
      char_count[i] = NA_INTEGER;
    }
    // Union of all rects (multi-line URLs span multiple).
    int rcount = FPDFLink_CountRects(lp, i);
    double L = R_PosInf, B = R_PosInf, R = R_NegInf, T = R_NegInf;
    bool any = false;
    for (int r = 0; r < rcount; ++r) {
      double rl = 0, rt = 0, rr = 0, rb = 0;
      if (FPDFLink_GetRect(lp, i, r, &rl, &rt, &rr, &rb)) {
        L = std::min(L, rl);
        T = std::max(T, rt);
        R = std::max(R, rr);
        B = std::min(B, rb);
        any = true;
      }
    }
    if (any) {
      left[i] = L; bottom[i] = B; right[i] = R; top[i] = T;
    } else {
      left[i] = bottom[i] = right[i] = top[i] = NA_REAL;
    }
  }

  FPDFLink_CloseWebLinks(lp);
  FPDFText_ClosePage(tp);

  return Rcpp::List::create(
    Rcpp::_["url"]        = url,
    Rcpp::_["start_char"] = start_char,
    Rcpp::_["char_count"] = char_count,
    Rcpp::_["left"]       = left,
    Rcpp::_["bottom"]     = bottom,
    Rcpp::_["right"]      = right,
    Rcpp::_["top"]        = top
  );
}
