// pdfium R package — shared helpers for classifying PDF action
// objects (FPDF_ACTION) and resolving destination details.
// Used by:
//   - src/doc.cpp (bookmark actions)
//   - src/page_nav.cpp (link-at-point + page additional-actions)
//   - src/page_extras.cpp (link enumeration)
//   - src/doc_extra.cpp (named destinations)
//
// PDFium represents actions as a small opaque handle whose type
// (GoTo, URI, Launch, RemoteGoTo, EmbeddedGoTo, Unsupported) selects
// which payload accessor is meaningful: GetURIPath for URI,
// GetFilePath for the file-based actions, and GetDest for any GoTo.
// classify_action() runs the type switch once.
//
// read_dest_details() resolves the location/view portion of a
// destination handle: which "view" mode (XYZ / Fit / FitH / FitV /
// FitR / FitB / FitBH / FitBV) and the optional (x, y, zoom)
// parameters that XYZ destinations carry. Values default to NA_REAL.
//
// Action and view types match the public PDFACTION_* / PDFDEST_VIEW_*
// values in fpdf_doc.h.

#ifndef PDFIUM_R_PKG_ACTION_HELPERS_H
#define PDFIUM_R_PKG_ACTION_HELPERS_H

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"

namespace pdfium_r {

// Resolve a destination handle to its view mode and (x, y, zoom)
// parameters. `view` is filled with the PDFDEST_VIEW_* code (0 =
// UNKNOWN); the floats hold NA_REAL when the destination doesn't
// specify them (e.g. /Fit has no x/y/zoom).
inline void read_dest_details(FPDF_DOCUMENT doc, FPDF_DEST dest,
                              int& view, double& x, double& y,
                              double& zoom) {
  view = 0;
  x = y = zoom = NA_REAL;
  if (dest == nullptr) return;
  unsigned long num_params = 0;
  FS_FLOAT params[4] = {0.f, 0.f, 0.f, 0.f};
  unsigned long v = FPDFDest_GetView(dest, &num_params, params);
  view = static_cast<int>(v);
  FPDF_BOOL has_x = 0, has_y = 0, has_zoom = 0;
  FS_FLOAT fx = 0.f, fy = 0.f, fz = 0.f;
  if (FPDFDest_GetLocationInPage(dest, &has_x, &has_y, &has_zoom,
                                  &fx, &fy, &fz)) {
    if (has_x)    x    = fx;
    if (has_y)    y    = fy;
    if (has_zoom) zoom = fz;
  }
  (void)doc;  // unused; kept in the signature for parallelism
}

inline void classify_action(FPDF_DOCUMENT doc,
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

// Extended variant of classify_action that also returns destination
// location/view. Callers that just need the basic info can keep
// using classify_action(); callers that want round-trippable
// destination details (bookmarks, links, named dests) use this
// variant.
inline void classify_action_with_dest(FPDF_DOCUMENT doc,
                                       FPDF_ACTION action,
                                       FPDF_DEST link_dest_fallback,
                                       int& action_code,
                                       std::string& uri_out,
                                       std::string& filepath_out,
                                       int& dest_page_idx,
                                       int& dest_view,
                                       double& dest_x,
                                       double& dest_y,
                                       double& dest_zoom) {
  classify_action(doc, action, action_code, uri_out, filepath_out,
                  dest_page_idx);
  FPDF_DEST dest =
      (action != nullptr) ? FPDFAction_GetDest(doc, action)
                          : link_dest_fallback;
  if (dest != nullptr && dest_page_idx < 0) {
    int p = FPDFDest_GetDestPageIndex(doc, dest);
    if (p >= 0) dest_page_idx = p;
  }
  read_dest_details(doc, dest, dest_view, dest_x, dest_y, dest_zoom);
}

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_ACTION_HELPERS_H
