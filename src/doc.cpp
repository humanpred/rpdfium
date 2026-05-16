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

// Resolve a bookmark's destination to a 1-based page number.
// Returns -1 when the bookmark has no dest (e.g. uses an action
// instead) or when the dest resolves to no page.
int bookmark_page_num(FPDF_DOCUMENT doc, FPDF_BOOKMARK bookmark) {
  FPDF_DEST dest = FPDFBookmark_GetDest(doc, bookmark);
  if (dest == nullptr) return -1;
  int idx = FPDFDest_GetDestPageIndex(doc, dest);
  return idx < 0 ? -1 : idx + 1;
}

// Depth-first walk over the bookmark tree, writing into the four
// flat output vectors. `parent_index` is 1-based into the bookmarks
// already emitted (or 0 for top-level entries).
void walk_bookmarks(FPDF_DOCUMENT doc,
                    FPDF_BOOKMARK current,
                    int parent_index,
                    int level,
                    std::vector<int>& parent_indices,
                    std::vector<int>& levels,
                    std::vector<std::string>& titles,
                    std::vector<int>& page_nums) {
  while (current != nullptr) {
    parent_indices.push_back(parent_index);
    levels.push_back(level);
    titles.push_back(read_bookmark_title(current));
    page_nums.push_back(bookmark_page_num(doc, current));
    int this_index = static_cast<int>(parent_indices.size());

    FPDF_BOOKMARK child = FPDFBookmark_GetFirstChild(doc, current);
    if (child != nullptr) {
      walk_bookmarks(doc, child, this_index, level + 1,
                     parent_indices, levels, titles, page_nums);
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

  FPDF_BOOKMARK root = FPDFBookmark_GetFirstChild(doc, nullptr);
  walk_bookmarks(doc, root, /*parent=*/0, /*level=*/1,
                 parent_indices, levels, titles, page_nums);

  return Rcpp::List::create(
      Rcpp::_["parent_index"] = parent_indices,
      Rcpp::_["level"]        = levels,
      Rcpp::_["title"]        = titles,
      Rcpp::_["page_num"]     = page_nums);
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
