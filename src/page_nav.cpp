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
#include "action_helpers.h"
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
      Rcpp::_["dest_page"]   = NA_INTEGER,
      Rcpp::_["dest_view"]   = NA_INTEGER,
      Rcpp::_["dest_x"]      = NA_REAL,
      Rcpp::_["dest_y"]      = NA_REAL,
      Rcpp::_["dest_zoom"]   = NA_REAL
    );
  }
  int z = FPDFLink_GetLinkZOrderAtPoint(page, x, y);
  double left = NA_REAL, bottom = NA_REAL, right = NA_REAL, top = NA_REAL;
  FS_RECTF r;
  if (FPDFLink_GetAnnotRect(link, &r)) {
    left = r.left; bottom = r.bottom; right = r.right; top = r.top;
  }
  FPDF_ACTION action = FPDFLink_GetAction(link);
  int action_code = 0, dest_page_idx = -1, dest_view = 0;
  double dest_x = NA_REAL, dest_y = NA_REAL, dest_zoom = NA_REAL;
  std::string uri, filepath;
  pdfium_r::classify_action(doc, action, action_code, uri, filepath,
                            dest_page_idx);
  FPDF_DEST dest_handle =
      (action != nullptr) ? FPDFAction_GetDest(doc, action)
                          : FPDFLink_GetDest(doc, link);
  if (dest_handle != nullptr) {
    if (dest_page_idx < 0) {
      int p = FPDFDest_GetDestPageIndex(doc, dest_handle);
      if (p >= 0) dest_page_idx = p;
    }
    pdfium_r::read_dest_details(doc, dest_handle, dest_view,
                                 dest_x, dest_y, dest_zoom);
  }
  if (action == nullptr) {
    action_code = 1;  // PDFACTION_GOTO for /Dest-only links
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
                                                  : (dest_page_idx + 1),
    Rcpp::_["dest_view"]   = dest_view,
    Rcpp::_["dest_x"]      = dest_x,
    Rcpp::_["dest_y"]      = dest_y,
    Rcpp::_["dest_zoom"]   = dest_zoom
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
  std::vector<int> dest_views;
  std::vector<double> dest_xs, dest_ys, dest_zooms;

  for (size_t i = 0; i < sizeof(kAATypes) / sizeof(int); ++i) {
    FPDF_ACTION action = FPDF_GetPageAAction(page, kAATypes[i]);
    if (action == nullptr) continue;
    int action_code = 0, dest = -1, dview = 0;
    double dx = NA_REAL, dy = NA_REAL, dzoom = NA_REAL;
    std::string uri, fp;
    pdfium_r::classify_action(doc, action, action_code, uri, fp, dest);
    FPDF_DEST dest_handle = FPDFAction_GetDest(doc, action);
    if (dest_handle != nullptr) {
      pdfium_r::read_dest_details(doc, dest_handle, dview, dx, dy,
                                   dzoom);
    }
    trigger.emplace_back(kAANames[i]);
    action_codes.push_back(action_code);
    uris.emplace_back(uri);
    filepaths.emplace_back(fp);
    dest_pages.push_back(dest < 0 ? NA_INTEGER : dest + 1);
    dest_views.push_back(dview);
    dest_xs.push_back(dx);
    dest_ys.push_back(dy);
    dest_zooms.push_back(dzoom);
  }
  return Rcpp::List::create(
    Rcpp::_["trigger"]     = trigger,
    Rcpp::_["action_code"] = action_codes,
    Rcpp::_["uri"]         = uris,
    Rcpp::_["filepath"]    = filepaths,
    Rcpp::_["dest_page"]   = dest_pages,
    Rcpp::_["dest_view"]   = dest_views,
    Rcpp::_["dest_x"]      = dest_xs,
    Rcpp::_["dest_y"]      = dest_ys,
    Rcpp::_["dest_zoom"]   = dest_zooms
  );
}
