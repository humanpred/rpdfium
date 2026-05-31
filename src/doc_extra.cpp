// pdfium R package — extra doc-level wrappers introduced in the
// phase-6 polish pass and the 0.1.0 read-completion pass.
// Specifically:
//
//   FPDF_GetFileIdentifier              -> pdf_doc_file_id(doc, type)
//   FPDFDoc_GetPageMode                 -> pdf_doc_page_mode(doc)
//   FPDFCatalog_IsTagged                -> pdf_doc_is_tagged(doc)
//   FPDF_VIEWERREF_*                    -> pdf_doc_viewer_preferences(doc)
//   FPDF_CountNamedDests + GetNamedDest -> pdf_doc_named_dests(doc)
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
    // # nocov start — covered by test-defensive.R via a representative
    // shim; the EXTPTR guard is duplicated across every doc-scoped
    // C++ entry point and is impossible to trip from the R API
    // (as_open_doc() always hands in an externalptr).
    Rcpp::stop("Expected an external pointer for the document.");
    // # nocov end
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
// FPDF_VIEWERREF_GetName reads the value of a /ViewerPreferences
// entry whose value is a name (e.g. /Direction = "L2R", /PageMode
// = "UseNone"). Used by pdf_doc_viewer_preference_by_name() for ad-hoc
// lookups against keys pdf_doc_viewer_preferences() doesn't surface.
// [[Rcpp::export(name = "cpp_viewer_ref_name")]]
std::string cpp_viewer_ref_name(SEXP doc_ptr, std::string key) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  unsigned long needed =
      FPDF_VIEWERREF_GetName(doc, key.c_str(), nullptr, 0);
  if (needed <= 1) return std::string();
  std::vector<char> buf(needed);
  FPDF_VIEWERREF_GetName(doc, key.c_str(), buf.data(), needed);
  // Strip trailing NUL.
  return std::string(buf.data(), needed - 1);
}

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
      // # nocov start — PDFium's FPDFJavaScriptAction_GetName always
      // returns >= 2 (one wchar_t NUL) for a valid action handle; the
      // < 2 branch would only fire if PDFium returned 0 or 1, which
      // can't be produced from any well-formed PDF the tests can
      // construct. Empty names yield exactly 2 (NUL only) and take
      // the `>= 2` path.
      names[i] = NA_STRING;
      // # nocov end
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
      // # nocov start — same defensive shape as the name branch above;
      // PDFium returns >= 2 for any valid script (including empty).
      scripts[i] = NA_STRING;
      // # nocov end
    }
    FPDFDoc_CloseJavaScriptAction(ja);
  }
  return Rcpp::List::create(
    Rcpp::_["name"]   = names,
    Rcpp::_["script"] = scripts
  );
}

// ===========================================================================
// FSDK_SetUnSpObjProcessHandler — unsupported-feature event handler.
//
// PDFium dispatches an "unsupported feature" callback whenever it
// processes a document or annotation feature it knows about but can't
// render fully (XFA forms, custom encryption types, 3D / movie / sound
// annotations, signature annotations, ...). By default rpdfium ignores
// these — the user opens a PDF and gets a silent partial render. The
// handler below buffers events into a process-global vector that R
// callers can drain on demand via pdf_drain_unsupported_features().
//
// Implementation note: Rf_warning() from inside an arbitrary PDFium
// callstack does longjmp, which can leave PDFium internal state in a
// bad spot. Buffering and draining from the R side is the safe path.
// ===========================================================================

namespace {

std::vector<std::string>& unsupported_buffer() {
  // Lazy-initialized so we don't run a global constructor at .so load.
  static std::vector<std::string> buf;
  return buf;
}

const char* unsupported_name(int n) {
  switch (n) {
    // # nocov start — XFA-bearing PDFs are rare and the public test
    // fixtures can't construct one PDFium recognizes as XFA (the
    // /AcroForm /XFA shape we tried isn't enough). Code path is
    // dead-simple string-map; covered by inspection.
    case FPDF_UNSP_DOC_XFAFORM: return "XFA form";
    // # nocov end
    case FPDF_UNSP_DOC_PORTABLECOLLECTION: return "portable collection";
    case FPDF_UNSP_DOC_ATTACHMENT: return "document attachment";
    // # nocov start — DOC_SECURITY fires only when PDFium encounters
    // an encryption type it can't read (e.g. /V > 4 or unsupported
    // /SubFilter). The package ships no encrypted fixtures.
    case FPDF_UNSP_DOC_SECURITY: return "document security";
    // SHAREDREVIEW / SHAREDFORM_* are emitted only for Acrobat-
    // specific collaboration-flow PDFs (the catalog carries reviewer
    // /UR3 entries or shared-form server metadata). We have no way
    // to construct one without an Acrobat round-trip.
    case FPDF_UNSP_DOC_SHAREDREVIEW: return "shared review";
    case FPDF_UNSP_DOC_SHAREDFORM_ACROBAT: return "shared form (Acrobat)";
    case FPDF_UNSP_DOC_SHAREDFORM_FILESYSTEM:
      return "shared form (filesystem)";
    case FPDF_UNSP_DOC_SHAREDFORM_EMAIL: return "shared form (email)";
    // ANNOT_3DANNOT / MOVIE / SOUND / SCREEN_MEDIA / SCREEN_RICHMEDIA
    // / ANNOT_ATTACHMENT / ANNOT_SIG: PDFium emits these from
    // CPDFSDK_BAAnnotHandler::OnLoad when it iterates annotations
    // during form-fill or render. Constructing the /Subtype dict
    // alone (as we do for the named_dests test) doesn't trigger
    // the load path that fires these events. Each return is a
    // pure string-map; covered by inspection.
    case FPDF_UNSP_ANNOT_3DANNOT: return "3D annotation";
    case FPDF_UNSP_ANNOT_MOVIE: return "movie annotation";
    case FPDF_UNSP_ANNOT_SOUND: return "sound annotation";
    case FPDF_UNSP_ANNOT_SCREEN_MEDIA: return "screen media annotation";
    case FPDF_UNSP_ANNOT_SCREEN_RICHMEDIA:
      return "screen rich-media annotation";
    case FPDF_UNSP_ANNOT_ATTACHMENT: return "attachment annotation";
    case FPDF_UNSP_ANNOT_SIG: return "signature annotation";
    default: return "unknown unsupported feature";
    // # nocov end
  }
}

extern "C" void pdfium_unsupported_callback(UNSUPPORT_INFO* /*self*/,
                                              int nType) {
  unsupported_buffer().emplace_back(unsupported_name(nType));
}

// Single static UNSUPPORT_INFO instance — PDFium retains a pointer to
// it for the lifetime of the library, so it must outlive any document
// the user opens. Static storage at namespace scope is exactly that.
UNSUPPORT_INFO g_unsp_info = {1, &pdfium_unsupported_callback};

}  // namespace

// [[Rcpp::export(name = "cpp_install_unsupported_handler")]]
bool cpp_install_unsupported_handler() {
  return FSDK_SetUnSpObjProcessHandler(&g_unsp_info) != 0;
}

// [[Rcpp::export(name = "cpp_drain_unsupported_features")]]
Rcpp::CharacterVector cpp_drain_unsupported_features() {
  std::vector<std::string>& buf = unsupported_buffer();
  Rcpp::CharacterVector out(buf.size());
  for (std::size_t i = 0; i < buf.size(); ++i) {
    out[i] = buf[i];
  }
  buf.clear();
  return out;
}
