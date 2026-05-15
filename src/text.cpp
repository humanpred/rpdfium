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

  // First call with NULL/0 sizes the buffer. PDFium's contract is:
  // the return value is the number of BYTES (not FPDF_WCHARs)
  // including the trailing UTF-16 NUL terminator. So a buffer
  // holding "Hello" returns 12 (5 chars + 1 NUL, each char being
  // 2 bytes UTF-16LE).
  unsigned long n_bytes =
      FPDFTextObj_GetText(obj, text_page, nullptr, 0UL);
  std::string utf8;
  if (n_bytes >= 2) {  // at least one FPDF_WCHAR (the NUL)
    size_t n_wchars = n_bytes / 2;
    std::vector<unsigned short> buf(n_wchars);
    FPDFTextObj_GetText(obj, text_page, buf.data(), n_bytes);
    // Strip the trailing NUL FPDF_WCHAR.
    size_t n_chars = n_wchars - 1;
    utf8 = utf16le_to_utf8(buf.data(), n_chars);
  }
  FPDFText_ClosePage(text_page);

  SEXP r_chr = PROTECT(Rf_mkCharLenCE(
      utf8.data(), static_cast<int>(utf8.size()), CE_UTF8));
  SEXP r_vec = PROTECT(Rf_allocVector(STRSXP, 1));
  SET_STRING_ELT(r_vec, 0, r_chr);
  UNPROTECT(2);
  return r_vec;
}
