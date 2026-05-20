// pdfium R package — per-bookmark handle shims.
//
// PDFium has no documented FPDFBookmark_Close call; bookmarks are
// owned by their parent FPDF_DOCUMENT, mirroring attachments and
// signatures. The R wrapper accordingly stores each handle in an
// externalptr WITHOUT a finalizer; the `prot` slot pins the parent
// doc.
//
// Unlike attachments/signatures, the bookmark outline is a tree, so
// `cpp_bookmark_handles` walks it depth-first and emits a flat list
// of handles in pre-order plus parallel `parent_index` / `level`
// vectors. The R side reconstructs the tree from those columns.

#include <Rcpp.h>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"
#include "action_helpers.h"
#include "handle_validation.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

FPDF_BOOKMARK bm_from_ptr(SEXP bm_ptr) {
  // Bookmark is doc-owned (no finalizer); prot pins the parent doc.
  return static_cast<FPDF_BOOKMARK>(
      pdfium_r::validate_handle(bm_ptr, "Bookmark",
                                  /*require_prot_alive=*/true));
}

// Depth-first walk over the bookmark tree, collecting handles plus
// structural (parent_index, level) parallel vectors.
void collect_bookmarks(FPDF_DOCUMENT doc, FPDF_BOOKMARK current,
                        int parent_index, int level,
                        std::vector<FPDF_BOOKMARK>& bms,
                        std::vector<int>& parent_indices,
                        std::vector<int>& levels) {
  while (current != nullptr) {
    bms.push_back(current);
    parent_indices.push_back(parent_index);
    levels.push_back(level);
    int this_index = static_cast<int>(bms.size());
    FPDF_BOOKMARK child = FPDFBookmark_GetFirstChild(doc, current);
    if (child != nullptr) {
      collect_bookmarks(doc, child, this_index, level + 1,
                         bms, parent_indices, levels);
    }
    current = FPDFBookmark_GetNextSibling(doc, current);
  }
}

std::string read_bookmark_title(FPDF_BOOKMARK bookmark) {
  unsigned long needed = FPDFBookmark_GetTitle(bookmark, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDFBookmark_GetTitle(bookmark, buf.data(), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

}  // namespace

// [[Rcpp::export(name = "cpp_bookmark_handles")]]
Rcpp::List cpp_bookmark_handles(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  std::vector<FPDF_BOOKMARK> bms;
  std::vector<int> parent_indices;
  std::vector<int> levels;
  FPDF_BOOKMARK root = FPDFBookmark_GetFirstChild(doc, nullptr);
  collect_bookmarks(doc, root, /*parent=*/0, /*level=*/1,
                     bms, parent_indices, levels);
  Rcpp::List handles(bms.size());
  for (size_t i = 0; i < bms.size(); ++i) {
    // No finalizer; doc owns the bookmark. prot slot pins the doc
    // (mirrors attachment / signature lifetimes).
    handles[i] = R_MakeExternalPtr(static_cast<void*>(bms[i]),
                                    R_NilValue, doc_ptr);
  }
  return Rcpp::List::create(
      Rcpp::_["handles"]        = handles,
      Rcpp::_["parent_indices"] = parent_indices,
      Rcpp::_["levels"]         = levels);
}

// [[Rcpp::export(name = "cpp_bookmark_title_handle")]]
std::string cpp_bookmark_title_handle(SEXP bm_ptr) {
  return read_bookmark_title(bm_from_ptr(bm_ptr));
}

// [[Rcpp::export(name = "cpp_bookmark_action_handle")]]
Rcpp::List cpp_bookmark_action_handle(SEXP bm_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_BOOKMARK bookmark = bm_from_ptr(bm_ptr);

  int action_code = 0;
  std::string uri, filepath;
  int dest_page_idx = -1;
  int dest_view = 0;
  double dest_x = NA_REAL, dest_y = NA_REAL, dest_zoom = NA_REAL;

  FPDF_ACTION action = FPDFBookmark_GetAction(bookmark);
  if (action != nullptr) {
    pdfium_r::classify_action(doc, action, action_code,
                               uri, filepath, dest_page_idx);
  }
  // Direct /Dest on the bookmark (overrides / supplements the action
  // dest for plain within-doc GoTo).
  FPDF_DEST dest = FPDFBookmark_GetDest(doc, bookmark);
  if (dest == nullptr && action != nullptr) {
    dest = FPDFAction_GetDest(doc, action);
  }
  if (dest != nullptr) {
    int idx = FPDFDest_GetDestPageIndex(doc, dest);
    if (idx >= 0) {
      dest_page_idx = idx;
      if (action == nullptr) {
        action_code = PDFACTION_GOTO;
      }
    }
    pdfium_r::read_dest_details(doc, dest, dest_view, dest_x, dest_y,
                                 dest_zoom);
  }

  return Rcpp::List::create(
      Rcpp::_["action_code"] = action_code,
      Rcpp::_["page_num"]    = dest_page_idx,
      Rcpp::_["uri"]         = uri,
      Rcpp::_["filepath"]    = filepath,
      Rcpp::_["dest_view"]   = dest_view,
      Rcpp::_["dest_x"]      = dest_x,
      Rcpp::_["dest_y"]      = dest_y,
      Rcpp::_["dest_zoom"]   = dest_zoom);
}
