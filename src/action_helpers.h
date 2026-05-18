// pdfium R package — shared helpers for classifying PDF action
// objects (FPDF_ACTION). Used by:
//   - src/doc.cpp (bookmark actions)
//   - src/page_nav.cpp (link-at-point + page additional-actions)
//
// PDFium represents actions as a small opaque handle whose type
// (GoTo, URI, Launch, RemoteGoTo, EmbeddedGoTo, Unsupported) selects
// which payload accessor is meaningful: GetURIPath for URI,
// GetFilePath for the file-based actions, and GetDest for any GoTo.
// classify_action() runs the type switch once and returns:
//   action_code   - PDFACTION_* enum value (0 for unsupported)
//   uri_out       - UTF-8 URL string for URI actions
//   filepath_out  - UTF-8 file path for file-based actions
//   dest_page_idx - 0-based destination page index, or -1 if none
//
// Action types match the public PDFACTION_* values in fpdf_doc.h.

#ifndef PDFIUM_R_PKG_ACTION_HELPERS_H
#define PDFIUM_R_PKG_ACTION_HELPERS_H

#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"

namespace pdfium_r {

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

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_ACTION_HELPERS_H
