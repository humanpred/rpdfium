// pdfium R package — extra doc-level wrappers introduced in the
// phase-6 polish pass and the 0.1.0 read-completion pass.
// Specifically:
//
//   FPDF_GetFileIdentifier              -> pdf_file_id(doc, type)
//   FPDFDoc_GetPageMode                 -> pdf_doc_page_mode(doc)
//   FPDFCatalog_IsTagged                -> pdf_doc_is_tagged(doc)
//   FPDF_VIEWERREF_*                    -> pdf_viewer_preferences(doc)
//   FPDF_CountNamedDests + GetNamedDest -> pdf_named_dests(doc)
//   FPDFDoc_GetJavaScriptAction* family -> pdf_doc_javascript(doc)
//
// All are document-scoped accessors that fit alongside pdf_doc_info()
// / pdf_doc_meta() but don't share enough code to live in
// src/document.cpp. Kept here so future extras can pile on without
// bloating the metadata module.

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_catalog.h"
#include "fpdf_doc.h"
#include "fpdf_ext.h"
#include "fpdf_javascript.h"
#include "action_helpers.h"
#include "utf16.h"

using pdfium_r::utf16le_to_utf8;

namespace {

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

}  // namespace

// [[Rcpp::export(name = "cpp_doc_file_id")]]
Rcpp::RawVector cpp_doc_file_id(SEXP doc_ptr, int id_type) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  // PDFium's FPDF_FILEIDTYPE is 0 (permanent) or 1 (changing). The
  // R wrapper validates the value before calling in.
  unsigned long needed = FPDF_GetFileIdentifier(
      doc, static_cast<FPDF_FILEIDTYPE>(id_type), nullptr, 0);
  if (needed <= 1) return Rcpp::RawVector(0);  // empty + NUL
  std::vector<unsigned char> buf(needed);
  FPDF_GetFileIdentifier(doc,
                          static_cast<FPDF_FILEIDTYPE>(id_type),
                          buf.data(), needed);
  // Strip the trailing NUL byte.
  size_t n = (needed >= 1 ? needed - 1 : needed);
  Rcpp::RawVector out(static_cast<R_xlen_t>(n));
  for (size_t i = 0; i < n; ++i) out[i] = buf[i];
  return out;
}

// [[Rcpp::export(name = "cpp_doc_page_mode")]]
int cpp_doc_page_mode(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  return FPDFDoc_GetPageMode(doc);
}

// [[Rcpp::export(name = "cpp_doc_is_tagged")]]
bool cpp_doc_is_tagged(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  return FPDFCatalog_IsTagged(doc) != 0;
}

// Viewer-preferences scalar dictionary entries. Returns:
//   $print_scaling     logical, default app pref or PDF override
//   $num_copies        integer, default 1
//   $duplex            character: "none" / "simplex" /
//                      "duplex_flip_short_edge" / "duplex_flip_long_edge"
//   $print_page_ranges integer vector of 1-based page numbers from the
//                      PrintPageRange array (empty if none specified)
// [[Rcpp::export(name = "cpp_doc_viewer_prefs")]]
Rcpp::List cpp_doc_viewer_prefs(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);

  bool print_scaling = FPDF_VIEWERREF_GetPrintScaling(doc) != 0;
  int num_copies = FPDF_VIEWERREF_GetNumCopies(doc);

  // FPDF_DUPLEXTYPE: DuplexUndefined=0, Simplex=1,
  // DuplexFlipShortEdge=2, DuplexFlipLongEdge=3. The R side maps
  // this to a string by index in .pdfium_duplex_modes.
  int duplex_code = static_cast<int>(FPDF_VIEWERREF_GetDuplex(doc));

  FPDF_PAGERANGE pr = FPDF_VIEWERREF_GetPrintPageRange(doc);
  Rcpp::IntegerVector pages;
  if (pr != nullptr) {
    size_t count = FPDF_VIEWERREF_GetPrintPageRangeCount(pr);
    pages = Rcpp::IntegerVector(static_cast<R_xlen_t>(count));
    for (size_t i = 0; i < count; ++i) {
      // Element is a 0-based page index; +1 for the R-facing value.
      pages[static_cast<R_xlen_t>(i)] =
          FPDF_VIEWERREF_GetPrintPageRangeElement(pr, i) + 1;
    }
  }

  return Rcpp::List::create(
    Rcpp::_["print_scaling"]      = print_scaling,
    Rcpp::_["num_copies"]         = num_copies,
    Rcpp::_["duplex_code"]        = duplex_code,
    Rcpp::_["print_page_ranges"]  = pages
  );
}

// Named-destination table. Each entry has a UTF-8 name and a 0-based
// destination page index (which the R side bumps to 1-based).
// Returns parallel vectors: $name (character), $page_index_zero
// (integer; will become $page on the R side).
// [[Rcpp::export(name = "cpp_doc_named_dests")]]
Rcpp::List cpp_doc_named_dests(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  int n = FPDF_CountNamedDests(doc);
  if (n <= 0) {
    return Rcpp::List::create(
      Rcpp::_["name"]             = Rcpp::CharacterVector(0),
      Rcpp::_["page_index_zero"]  = Rcpp::IntegerVector(0),
      Rcpp::_["dest_view"]        = Rcpp::IntegerVector(0),
      Rcpp::_["dest_x"]           = Rcpp::NumericVector(0),
      Rcpp::_["dest_y"]           = Rcpp::NumericVector(0),
      Rcpp::_["dest_zoom"]        = Rcpp::NumericVector(0)
    );
  }
  Rcpp::CharacterVector names(n);
  Rcpp::IntegerVector page_index_zero(n);
  Rcpp::IntegerVector dest_view(n);
  Rcpp::NumericVector dest_x(n), dest_y(n), dest_zoom(n);
  for (int i = 0; i < n; ++i) {
    // Two-pass byte-count probe: buflen in/out (bytes).
    long buflen = 0;
    FPDF_DEST dest = FPDF_GetNamedDest(doc, i, nullptr, &buflen);
    if (dest == nullptr || buflen <= 0) {
      names[i] = NA_STRING;
      page_index_zero[i] = NA_INTEGER;
      dest_view[i] = 0;
      dest_x[i] = dest_y[i] = dest_zoom[i] = NA_REAL;
      continue;
    }
    std::vector<unsigned short> buf(static_cast<size_t>(buflen) / 2);
    long buflen2 = buflen;
    FPDF_GetNamedDest(doc, i, buf.data(), &buflen2);
    size_t n_wchars = static_cast<size_t>(buflen2) / 2;
    // Strip trailing NUL.
    if (n_wchars > 0 && buf[n_wchars - 1] == 0) --n_wchars;
    std::string utf8 = utf16le_to_utf8(buf.data(), n_wchars);
    names[i] = Rf_mkCharLenCE(utf8.data(), static_cast<int>(utf8.size()),
                              CE_UTF8);
    int p = FPDFDest_GetDestPageIndex(doc, dest);
    page_index_zero[i] = (p < 0) ? NA_INTEGER : p;
    int view = 0;
    double x = NA_REAL, y = NA_REAL, zoom = NA_REAL;
    pdfium_r::read_dest_details(doc, dest, view, x, y, zoom);
    dest_view[i] = view;
    dest_x[i]    = x;
    dest_y[i]    = y;
    dest_zoom[i] = zoom;
  }
  return Rcpp::List::create(
    Rcpp::_["name"]             = names,
    Rcpp::_["page_index_zero"]  = page_index_zero,
    Rcpp::_["dest_view"]        = dest_view,
    Rcpp::_["dest_x"]           = dest_x,
    Rcpp::_["dest_y"]           = dest_y,
    Rcpp::_["dest_zoom"]        = dest_zoom
  );
}

// Document-level JavaScript actions: returns parallel vectors of
// action names and script source (both UTF-8).
// [[Rcpp::export(name = "cpp_doc_javascript")]]
Rcpp::List cpp_doc_javascript(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  int n = FPDFDoc_GetJavaScriptActionCount(doc);
  if (n <= 0) {
    return Rcpp::List::create(
      Rcpp::_["name"]   = Rcpp::CharacterVector(0),
      Rcpp::_["script"] = Rcpp::CharacterVector(0)
    );
  }
  Rcpp::CharacterVector names(n);
  Rcpp::CharacterVector scripts(n);
  for (int i = 0; i < n; ++i) {
    FPDF_JAVASCRIPT_ACTION ja = FPDFDoc_GetJavaScriptAction(doc, i);
    if (ja == nullptr) {
      names[i] = NA_STRING;
      scripts[i] = NA_STRING;
      continue;
    }
    // Two-pass for name.
    unsigned long need = FPDFJavaScriptAction_GetName(ja, nullptr, 0);
    if (need >= 2) {
      std::vector<unsigned short> nbuf(need / 2);
      FPDFJavaScriptAction_GetName(ja, nbuf.data(), need);
      size_t n_wchars = (need / 2) - 1;  // strip NUL
      std::string utf8 = utf16le_to_utf8(nbuf.data(), n_wchars);
      names[i] = Rf_mkCharLenCE(utf8.data(),
                                static_cast<int>(utf8.size()), CE_UTF8);
    } else {
      names[i] = NA_STRING;
    }
    // Two-pass for script.
    need = FPDFJavaScriptAction_GetScript(ja, nullptr, 0);
    if (need >= 2) {
      std::vector<unsigned short> sbuf(need / 2);
      FPDFJavaScriptAction_GetScript(ja, sbuf.data(), need);
      size_t n_wchars = (need / 2) - 1;
      std::string utf8 = utf16le_to_utf8(sbuf.data(), n_wchars);
      scripts[i] = Rf_mkCharLenCE(utf8.data(),
                                  static_cast<int>(utf8.size()), CE_UTF8);
    } else {
      scripts[i] = NA_STRING;
    }
    FPDFDoc_CloseJavaScriptAction(ja);
  }
  return Rcpp::List::create(
    Rcpp::_["name"]   = names,
    Rcpp::_["script"] = scripts
  );
}
