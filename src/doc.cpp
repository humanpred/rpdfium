// pdfium R package — document-level readers (TOC / labels /
// permissions). Three independent PDFium features grouped here
// because each is small and they all take FPDF_DOCUMENT and return
// flat data without owning new handles:
//
//   FPDFBookmark_GetFirstChild / _GetNextSibling / _GetTitle /
//     _GetDest    — outline / table-of-contents enumeration
//   FPDFDest_GetDestPageIndex — destination -> page index resolution
//   FPDF_GetPageLabel          — logical "i, ii, 1, 2, ..." labels
//   FPDF_GetDocPermissions     — 32-bit permission bitmask
//
// Bookmark enumeration walks the tree depth-first and writes the
// hierarchy into flat parallel vectors that the R side wraps in a
// tibble with `bookmark_index`, `parent_index`, `level`, `title`,
// `page_num`. A bookmark's destination may resolve to a page index
// of -1 (no destination, or a remote/launch action); the R wrapper
// surfaces that as NA.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"
#include "action_helpers.h"
#include "utf16.h"

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

// Read a UTF-16LE bookmark title via the standard two-pass pattern.
std::string read_bookmark_title(FPDF_BOOKMARK bookmark) {
  unsigned long needed = FPDFBookmark_GetTitle(bookmark, nullptr, 0);
  if (needed <= 2) return std::string();  // empty + trailing NUL
  std::vector<unsigned short> buf(needed / 2);
  FPDFBookmark_GetTitle(bookmark, buf.data(), needed);
  // PDFium reports length in bytes including the trailing UTF-16
  // NUL (2 bytes). The shared utf16le_to_utf8 helper takes a code-
  // unit count, so divide by 2 and drop the trailing NUL.
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// Resolve a bookmark to its destination + action payload. A bookmark
// can declare:
//   * A /Dest entry pointing at a within-document page (the simplest
//     case PDFium's helper FPDFBookmark_GetDest handles directly).
//   * An /A action, which may itself be a GoTo (within-doc),
//     RemoteGoTo / Launch (other file), URI (web link), or
//     EmbeddedGoTo (into an attached file). When /A is present the
//     bookmark may *also* not carry an own /Dest.
// We surface both: the dest page index (preferring /Dest, falling
// back to the action's dest) plus the action's type / URI / file
// path. The R wrapper translates `action_code == 0` (no action and
// no dest) to "goto" with `dest_page == NA` for the typical "page
// destination not resolvable" case.
void read_bookmark_action(FPDF_DOCUMENT doc,
                          FPDF_BOOKMARK bookmark,
                          int& action_code,
                          std::string& uri_out,
                          std::string& filepath_out,
                          int& dest_page_idx,
                          int& dest_view,
                          double& dest_x,
                          double& dest_y,
                          double& dest_zoom) {
  // Default to "goto" semantics; classify_action will overwrite if an
  // /A is present, and we'll then fold in /Dest below.
  action_code = 0;
  uri_out.clear();
  filepath_out.clear();
  dest_page_idx = -1;
  dest_view = 0;
  dest_x = dest_y = dest_zoom = NA_REAL;

  FPDF_ACTION action = FPDFBookmark_GetAction(bookmark);
  if (action != nullptr) {
    pdfium_r::classify_action(doc, action, action_code,
                              uri_out, filepath_out, dest_page_idx);
  }
  // Direct /Dest on the bookmark (overrides / supplements any
  // action-derived dest_page_idx for plain within-doc GoTo).
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
}

// Depth-first walk over the bookmark tree, writing into the flat
// output vectors. `parent_index` is 1-based into the bookmarks
// already emitted (or 0 for top-level entries).
void walk_bookmarks(FPDF_DOCUMENT doc,
                    FPDF_BOOKMARK current,
                    int parent_index,
                    int level,
                    std::vector<int>& parent_indices,
                    std::vector<int>& levels,
                    std::vector<std::string>& titles,
                    std::vector<int>& page_nums,
                    std::vector<int>& action_codes,
                    std::vector<std::string>& uris,
                    std::vector<std::string>& filepaths,
                    std::vector<int>& dest_views,
                    std::vector<double>& dest_xs,
                    std::vector<double>& dest_ys,
                    std::vector<double>& dest_zooms) {
  while (current != nullptr) {
    int action_code = 0, dest_page_idx = -1, dest_view = 0;
    double dest_x = NA_REAL, dest_y = NA_REAL, dest_zoom = NA_REAL;
    std::string uri, filepath;
    read_bookmark_action(doc, current, action_code, uri, filepath,
                         dest_page_idx,
                         dest_view, dest_x, dest_y, dest_zoom);

    parent_indices.push_back(parent_index);
    levels.push_back(level);
    titles.push_back(read_bookmark_title(current));
    page_nums.push_back(dest_page_idx < 0 ? -1 : dest_page_idx + 1);
    action_codes.push_back(action_code);
    uris.emplace_back(uri);
    filepaths.emplace_back(filepath);
    dest_views.push_back(dest_view);
    dest_xs.push_back(dest_x);
    dest_ys.push_back(dest_y);
    dest_zooms.push_back(dest_zoom);
    int this_index = static_cast<int>(parent_indices.size());

    FPDF_BOOKMARK child = FPDFBookmark_GetFirstChild(doc, current);
    if (child != nullptr) {
      walk_bookmarks(doc, child, this_index, level + 1,
                     parent_indices, levels, titles, page_nums,
                     action_codes, uris, filepaths,
                     dest_views, dest_xs, dest_ys, dest_zooms);
    }
    current = FPDFBookmark_GetNextSibling(doc, current);
  }
}

}  // namespace

// [[Rcpp::export(name = "cpp_bookmarks")]]
Rcpp::List cpp_bookmarks(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);

  std::vector<int> parent_indices;
  std::vector<int> levels;
  std::vector<std::string> titles;
  std::vector<int> page_nums;
  std::vector<int> action_codes;
  std::vector<std::string> uris;
  std::vector<std::string> filepaths;
  std::vector<int> dest_views;
  std::vector<double> dest_xs, dest_ys, dest_zooms;

  FPDF_BOOKMARK root = FPDFBookmark_GetFirstChild(doc, nullptr);
  walk_bookmarks(doc, root, /*parent=*/0, /*level=*/1,
                 parent_indices, levels, titles, page_nums,
                 action_codes, uris, filepaths,
                 dest_views, dest_xs, dest_ys, dest_zooms);

  return Rcpp::List::create(
      Rcpp::_["parent_index"] = parent_indices,
      Rcpp::_["level"]        = levels,
      Rcpp::_["title"]        = titles,
      Rcpp::_["page_num"]     = page_nums,
      Rcpp::_["action_code"]  = action_codes,
      Rcpp::_["uri"]          = uris,
      Rcpp::_["filepath"]     = filepaths,
      Rcpp::_["dest_view"]    = dest_views,
      Rcpp::_["dest_x"]       = dest_xs,
      Rcpp::_["dest_y"]       = dest_ys,
      Rcpp::_["dest_zoom"]    = dest_zooms);
}

// [[Rcpp::export(name = "cpp_page_label")]]
std::string cpp_page_label(SEXP doc_ptr, int page_index_zero) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  unsigned long needed =
      FPDF_GetPageLabel(doc, page_index_zero, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDF_GetPageLabel(doc, page_index_zero, buf.data(), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// [[Rcpp::export(name = "cpp_doc_permissions")]]
double cpp_doc_permissions(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  // FPDF_GetDocPermissions returns an unsigned 32-bit integer.
  // Promote to double so R sees the full 32-bit range (R's integer
  // is 32-bit signed and cannot hold 0xFFFFFFFF). The R wrapper
  // bit-decodes this into a per-flag named logical vector.
  return static_cast<double>(FPDF_GetDocPermissions(doc));
}
