// pdfium R package — text-object accessors.
//
// Phase 1 shipped the font-size getter; Phase 3 adds content
// extraction. FPDFTextObj_GetText requires a FPDF_TEXTPAGE for
// per-character context (CMaps, encoding); we load and close the
// text page transparently inside cpp_text_content so callers don't
// need a separate handle. Future slices that read many text objects
// from one page should switch to a batched variant that loads the
// text page once.

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "fpdf_text.h"

namespace {

// Convert a buffer of FPDF_WCHAR (unsigned short, UTF-16LE) to a
// UTF-8 std::string. Handles surrogate pairs for code points >=
// 0x10000. Trailing null terminators emitted by FPDFTextObj_GetText
// are skipped by the caller before allocating the R string.
std::string utf16le_to_utf8(const unsigned short* buf, size_t n) {
  std::string out;
  out.reserve(n);
  for (size_t i = 0; i < n; ++i) {
    unsigned int cp = buf[i];
    if (cp >= 0xD800 && cp < 0xDC00 && i + 1 < n) {
      unsigned int low = buf[i + 1];
      if (low >= 0xDC00 && low < 0xE000) {
        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
        ++i;
      }
    }
    if (cp < 0x80) {
      out.push_back(static_cast<char>(cp));
    } else if (cp < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
  }
  return out;
}

}  // namespace

// [[Rcpp::export(name = "cpp_text_font_size")]]
double cpp_text_font_size(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) Rcpp::stop("Expected an external pointer.");
  FPDF_PAGEOBJECT obj = static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) Rcpp::stop("Page-object handle is closed.");
  float size = 0.0f;
  FPDF_BOOL ok = FPDFTextObj_GetFontSize(obj, &size);
  if (!ok) return NA_REAL;
  return static_cast<double>(size);
}

namespace {

// Read text for a single FPDF_PAGEOBJECT using an already-loaded
// FPDF_TEXTPAGE. Returns the decoded UTF-8 string. Caller owns the
// text page and is responsible for closing it.
std::string read_text_obj(FPDF_PAGEOBJECT obj, FPDF_TEXTPAGE text_page) {
  unsigned long n_bytes = FPDFTextObj_GetText(obj, text_page, nullptr, 0UL);
  if (n_bytes < 2) return std::string();
  size_t n_wchars = n_bytes / 2;
  std::vector<unsigned short> buf(n_wchars);
  FPDFTextObj_GetText(obj, text_page, buf.data(), n_bytes);
  return utf16le_to_utf8(buf.data(), n_wchars - 1);
}

}  // namespace

// [[Rcpp::export(name = "cpp_text_content")]]
SEXP cpp_text_content(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) Rcpp::stop("Expected an external pointer.");
  FPDF_PAGEOBJECT obj = static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) Rcpp::stop("Page-object handle is closed.");

  // Recover the parent FPDF_PAGE via the externalptr's prot slot,
  // which we set in cpp_page_get_object() (see src/objects.cpp).
  SEXP page_ptr = R_ExternalPtrProtected(obj_ptr);
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Page-object externalptr has no parent-page reference.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Parent page is closed.");

  FPDF_TEXTPAGE text_page = FPDFText_LoadPage(page);
  if (text_page == nullptr) {
    Rcpp::stop("FPDFText_LoadPage returned NULL.");
  }

  std::string utf8 = read_text_obj(obj, text_page);
  FPDFText_ClosePage(text_page);

  SEXP r_chr = PROTECT(Rf_mkCharLenCE(
      utf8.data(), static_cast<int>(utf8.size()), CE_UTF8));
  SEXP r_vec = PROTECT(Rf_allocVector(STRSXP, 1));
  SET_STRING_ELT(r_vec, 0, r_chr);
  UNPROTECT(2);
  return r_vec;
}

// [[Rcpp::export(name = "cpp_page_text_runs")]]
Rcpp::List cpp_page_text_runs(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) Rcpp::stop("Expected an external pointer.");
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");

  FPDF_TEXTPAGE text_page = FPDFText_LoadPage(page);
  if (text_page == nullptr) {
    Rcpp::stop("FPDFText_LoadPage returned NULL.");
  }

  int n = FPDFPage_CountObjects(page);
  // Two-pass: count text objects to size vectors exactly, then fill.
  std::vector<int> text_indices;
  for (int i = 0; i < n; ++i) {
    FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page, i);
    if (obj != nullptr && FPDFPageObj_GetType(obj) == FPDF_PAGEOBJ_TEXT) {
      text_indices.push_back(i + 1);  // 1-based for the R-facing index
    }
  }

  size_t m = text_indices.size();
  Rcpp::IntegerVector index(m);
  Rcpp::NumericVector left(m), bottom(m), right(m), top(m), font_size(m);
  Rcpp::CharacterVector text(m);

  for (size_t k = 0; k < m; ++k) {
    int i = text_indices[k] - 1;
    FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page, i);

    index[k] = text_indices[k];

    float l = 0.0f, b = 0.0f, r = 0.0f, t = 0.0f;
    if (FPDFPageObj_GetBounds(obj, &l, &b, &r, &t)) {
      left[k]   = static_cast<double>(l);
      bottom[k] = static_cast<double>(b);
      right[k]  = static_cast<double>(r);
      top[k]    = static_cast<double>(t);
    } else {
      left[k] = bottom[k] = right[k] = top[k] = NA_REAL;
    }

    float fs = 0.0f;
    if (FPDFTextObj_GetFontSize(obj, &fs)) {
      font_size[k] = static_cast<double>(fs);
    } else {
      font_size[k] = NA_REAL;
    }

    std::string utf8 = read_text_obj(obj, text_page);
    text[k] = Rf_mkCharLenCE(utf8.data(), static_cast<int>(utf8.size()),
                             CE_UTF8);
  }

  FPDFText_ClosePage(text_page);

  return Rcpp::List::create(
    Rcpp::_["text_index"]    = index,
    Rcpp::_["bounds_left"]   = left,
    Rcpp::_["bounds_bottom"] = bottom,
    Rcpp::_["bounds_right"]  = right,
    Rcpp::_["bounds_top"]    = top,
    Rcpp::_["font_size"]     = font_size,
    Rcpp::_["text"]          = text
  );
}
