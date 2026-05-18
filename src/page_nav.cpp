// pdfium R package — page-level navigation extras.
//
// Adds two pieces of navigation surface:
//   FPDFLink_GetLinkAtPoint / GetLinkZOrderAtPoint
//                                  -> pdf_link_at_point(page, x, y)
//   FPDF_GetPageAAction (OPEN/CLOSE) + FPDFAction_* family
//                                  -> pdf_page_actions(page)
//
// The link-at-point readout returns a single-row tibble (or zero-row
// when no link is under the point). The page-action readout returns
// up to two rows, one per page additional-action type.

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"
#include "fpdf_formfill.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT nav_doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

FPDF_PAGE nav_page_from_ptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

// Helper: classify an FPDF_ACTION and extract its associated payload
// (URI string, file path, dest page index). Fills the output strings
// and `dest_page_idx` (-1 means none / unresolved).
void classify_action(FPDF_DOCUMENT doc,
                     FPDF_ACTION action,
                     int& action_code,
                     std::string& uri_out,
                     std::string& filepath_out,
                     int& dest_page_idx) {
  uri_out.clear();
  filepath_out.clear();
  dest_page_idx = -1;
  if (action == nullptr) {
    action_code = 0;  // PDFACTION_UNSUPPORTED
    return;
  }
  unsigned long t = FPDFAction_GetType(action);
  action_code = static_cast<int>(t);
  if (t == PDFACTION_URI) {
    unsigned long need = FPDFAction_GetURIPath(doc, action, nullptr, 0);
    if (need > 1) {
      std::vector<char> buf(need);
      FPDFAction_GetURIPath(doc, action, buf.data(), need);
      uri_out.assign(buf.data(), need - 1);
    }
  } else if (t == PDFACTION_REMOTEGOTO || t == PDFACTION_LAUNCH ||
             t == PDFACTION_EMBEDDEDGOTO) {
    unsigned long need = FPDFAction_GetFilePath(action, nullptr, 0);
    if (need > 1) {
      std::vector<char> buf(need);
      FPDFAction_GetFilePath(action, buf.data(), need);
      filepath_out.assign(buf.data(), need - 1);
    }
  }
  FPDF_DEST dest = FPDFAction_GetDest(doc, action);
  if (dest != nullptr) {
    int p = FPDFDest_GetDestPageIndex(doc, dest);
    if (p >= 0) dest_page_idx = p;
  }
}

}  // namespace

// Look up the link annotation under a given (x, y) on the page (in
// PDF user-space points). Returns a list with NA fields when no link
// is under the point.
// [[Rcpp::export(name = "cpp_link_at_point")]]
Rcpp::List cpp_link_at_point(SEXP doc_ptr, SEXP page_ptr,
                             double x, double y) {
  FPDF_DOCUMENT doc  = nav_doc_from_ptr(doc_ptr);
  FPDF_PAGE     page = nav_page_from_ptr(page_ptr);
  FPDF_LINK     link = FPDFLink_GetLinkAtPoint(page, x, y);
  if (link == nullptr) {
    return Rcpp::List::create(
      Rcpp::_["found"]       = false,
      Rcpp::_["z_order"]     = NA_INTEGER,
      Rcpp::_["left"]        = NA_REAL,
      Rcpp::_["bottom"]      = NA_REAL,
      Rcpp::_["right"]       = NA_REAL,
      Rcpp::_["top"]         = NA_REAL,
      Rcpp::_["action_code"] = NA_INTEGER,
      Rcpp::_["uri"]         = std::string(),
      Rcpp::_["filepath"]    = std::string(),
      Rcpp::_["dest_page"]   = NA_INTEGER
    );
  }
  int z = FPDFLink_GetLinkZOrderAtPoint(page, x, y);
  double left = NA_REAL, bottom = NA_REAL, right = NA_REAL, top = NA_REAL;
  FS_RECTF r;
  if (FPDFLink_GetAnnotRect(link, &r)) {
    left = r.left; bottom = r.bottom; right = r.right; top = r.top;
  }
  FPDF_ACTION action = FPDFLink_GetAction(link);
  int action_code = 0, dest_page_idx = -1;
  std::string uri, filepath;
  classify_action(doc, action, action_code, uri, filepath, dest_page_idx);
  // If no /A action, fall back to /Dest on the link itself.
  if (action == nullptr) {
    FPDF_DEST dest = FPDFLink_GetDest(doc, link);
    if (dest != nullptr) {
      int p = FPDFDest_GetDestPageIndex(doc, dest);
      if (p >= 0) dest_page_idx = p;
    }
    action_code = 1;  // PDFACTION_GOTO
  }
  return Rcpp::List::create(
    Rcpp::_["found"]       = true,
    Rcpp::_["z_order"]     = (z < 0) ? NA_INTEGER : z,
    Rcpp::_["left"]        = left,
    Rcpp::_["bottom"]      = bottom,
    Rcpp::_["right"]       = right,
    Rcpp::_["top"]         = top,
    Rcpp::_["action_code"] = action_code,
    Rcpp::_["uri"]         = uri,
    Rcpp::_["filepath"]    = filepath,
    Rcpp::_["dest_page"]   = (dest_page_idx < 0) ? NA_INTEGER
                                                  : (dest_page_idx + 1)
  );
}

// Page additional-actions (open / close). Returns one row per action
// type that's defined (zero, one, or two rows).
// [[Rcpp::export(name = "cpp_page_aactions")]]
Rcpp::List cpp_page_aactions(SEXP doc_ptr, SEXP page_ptr) {
  FPDF_DOCUMENT doc  = nav_doc_from_ptr(doc_ptr);
  FPDF_PAGE     page = nav_page_from_ptr(page_ptr);

  // aa_type values from fpdf_formfill.h:
  //   FPDFPAGE_AACTION_OPEN  = 0
  //   FPDFPAGE_AACTION_CLOSE = 1
  const int kAATypes[] = {FPDFPAGE_AACTION_OPEN, FPDFPAGE_AACTION_CLOSE};
  const char* kAANames[] = {"open", "close"};

  std::vector<std::string> trigger;
  std::vector<int> action_codes;
  std::vector<std::string> uris;
  std::vector<std::string> filepaths;
  std::vector<int> dest_pages;

  for (size_t i = 0; i < sizeof(kAATypes) / sizeof(int); ++i) {
    FPDF_ACTION action = FPDF_GetPageAAction(page, kAATypes[i]);
    if (action == nullptr) continue;
    int action_code = 0, dest = -1;
    std::string uri, fp;
    classify_action(doc, action, action_code, uri, fp, dest);
    trigger.emplace_back(kAANames[i]);
    action_codes.push_back(action_code);
    uris.emplace_back(uri);
    filepaths.emplace_back(fp);
    dest_pages.push_back(dest < 0 ? NA_INTEGER : dest + 1);
  }
  return Rcpp::List::create(
    Rcpp::_["trigger"]     = trigger,
    Rcpp::_["action_code"] = action_codes,
    Rcpp::_["uri"]         = uris,
    Rcpp::_["filepath"]    = filepaths,
    Rcpp::_["dest_page"]   = dest_pages
  );
}
