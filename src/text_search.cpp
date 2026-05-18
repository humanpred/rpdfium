// pdfium R package — text search across a single page via PDFium's
// FPDFText_Find* family.
//
// PDFium models page text as an indexable character sequence
// (FPDF_TEXTPAGE). Search is performed against that sequence:
//   - FPDFText_FindStart(tp, query, flags, start_idx) opens a handle.
//   - FPDFText_FindNext / FPDFText_FindPrev step through matches.
//   - FPDFText_GetSchResultIndex / FPDFText_GetSchCount report the
//     starting character offset and the length of the current match.
//   - FPDFText_GetText / FPDFText_GetCharBox give us the matched text
//     and per-character bounding boxes for highlighting.
//   - FPDFText_FindClose / FPDFText_ClosePage release everything.
//
// The R-facing entry point operates on one page at a time; iteration
// across the document lives in R/text_search.R so the C++ layer stays
// trivially testable with a single page handle.

#include <Rcpp.h>
#include <algorithm>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_text.h"
#include "utf16.h"

using pdfium_r::utf16le_to_utf8;
using pdfium_r::utf8_to_utf16le_nul;

// [[Rcpp::export(name = "cpp_text_search_page")]]
Rcpp::List cpp_text_search_page(SEXP page_ptr,
                                std::string query,
                                bool match_case,
                                bool match_whole_word,
                                bool consecutive) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");

  // Empty query is meaningless and would cause PDFium to loop. The R
  // wrapper rejects this earlier; this is belt-and-braces.
  if (query.empty()) {
    return Rcpp::List::create(
      Rcpp::_["start_char"] = Rcpp::IntegerVector(0),
      Rcpp::_["char_count"] = Rcpp::IntegerVector(0),
      Rcpp::_["text"]       = Rcpp::CharacterVector(0),
      Rcpp::_["left"]       = Rcpp::NumericVector(0),
      Rcpp::_["bottom"]     = Rcpp::NumericVector(0),
      Rcpp::_["right"]      = Rcpp::NumericVector(0),
      Rcpp::_["top"]        = Rcpp::NumericVector(0)
    );
  }

  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");

  // FPDF_MATCHCASE (0x1), FPDF_MATCHWHOLEWORD (0x2),
  // FPDF_CONSECUTIVE (0x4). Anything else would silently scope creep.
  unsigned long flags = 0UL;
  if (match_case)        flags |= 0x00000001UL;
  if (match_whole_word)  flags |= 0x00000002UL;
  if (consecutive)       flags |= 0x00000004UL;

  std::vector<unsigned short> wquery = utf8_to_utf16le_nul(query);
  FPDF_SCHHANDLE sh =
      FPDFText_FindStart(tp, wquery.data(), flags, /*start_index=*/0);
  if (sh == nullptr) {
    FPDFText_ClosePage(tp);
    Rcpp::stop("FPDFText_FindStart returned NULL.");
  }

  std::vector<int> starts;
  std::vector<int> counts;
  while (FPDFText_FindNext(sh)) {
    starts.push_back(FPDFText_GetSchResultIndex(sh));
    counts.push_back(FPDFText_GetSchCount(sh));
  }
  FPDFText_FindClose(sh);

  size_t n = starts.size();
  Rcpp::IntegerVector start_char(n), char_count(n);
  Rcpp::CharacterVector text(n);
  Rcpp::NumericVector left(n), bottom(n), right(n), top(n);

  for (size_t k = 0; k < n; ++k) {
    int s = starts[k];
    int c = counts[k];
    start_char[k] = s;
    char_count[k] = c;

    // Recover the matched substring exactly as it sits in the page.
    // FPDFText_GetText writes UTF-16LE into our buffer including a
    // trailing NUL, and returns the buffer-size in 16-bit units it
    // wrote (so c + 1 for a c-character match).
    std::vector<unsigned short> buf(static_cast<size_t>(c) + 1, 0);
    int written = FPDFText_GetText(tp, s, c, buf.data());
    int n_chars = std::max(0, written - 1);   // strip trailing NUL
    std::string utf8 = utf16le_to_utf8(buf.data(),
                                        static_cast<size_t>(n_chars));
    text[k] = Rf_mkCharLenCE(utf8.data(), static_cast<int>(utf8.size()),
                             CE_UTF8);

    // Bounding box: union of every char box in the match. PDFium's
    // FPDFText_GetCharBox returns (left, right, bottom, top) -- note
    // the unusual l/r/b/t parameter order in the C API.
    double L = R_PosInf, B = R_PosInf, R = R_NegInf, T = R_NegInf;
    bool any = false;
    for (int idx = s; idx < s + c; ++idx) {
      double cl = 0.0, cr = 0.0, cb = 0.0, ct = 0.0;
      if (FPDFText_GetCharBox(tp, idx, &cl, &cr, &cb, &ct)) {
        L = std::min(L, cl);
        B = std::min(B, cb);
        R = std::max(R, cr);
        T = std::max(T, ct);
        any = true;
      }
    }
    if (any) {
      left[k]   = L;
      bottom[k] = B;
      right[k]  = R;
      top[k]    = T;
    } else {
      left[k] = bottom[k] = right[k] = top[k] = NA_REAL;
    }
  }

  FPDFText_ClosePage(tp);

  return Rcpp::List::create(
    Rcpp::_["start_char"] = start_char,
    Rcpp::_["char_count"] = char_count,
    Rcpp::_["text"]       = text,
    Rcpp::_["left"]       = left,
    Rcpp::_["bottom"]     = bottom,
    Rcpp::_["right"]      = right,
    Rcpp::_["top"]        = top
  );
}
