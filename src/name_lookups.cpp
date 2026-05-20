// pdfium R package — name- and point-based lookups that don't fit
// the bulk enumeration readers. Three small accessors:
//
//   FPDF_GetNamedDestByName            pdf_named_dest(doc, name)
//   FPDFBookmark_Find                  pdf_doc_bookmark_find(doc, title)
//   FPDFAnnot_GetFormFieldAtPoint /
//   FPDFPage_HasFormFieldAtPoint /
//   FPDFPage_FormFieldZOrderAtPoint    pdf_form_field_at_point(page, x, y)
//
// All three resolve to identity/index data; richer details come from
// the bulk enumerators (pdf_doc_named_dests / pdf_doc_bookmarks /
// pdf_form_fields).

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_doc.h"
#include "fpdf_formfill.h"
#include "action_helpers.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT lookups_doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

FPDF_PAGE lookups_page_from_ptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

}  // namespace

// Returns the 1-based destination page and dest view/x/y/zoom for a
// named destination, or NA fields when the name doesn't exist.
// [[Rcpp::export(name = "cpp_named_dest_by_name")]]
Rcpp::List cpp_named_dest_by_name(SEXP doc_ptr, std::string name) {
  FPDF_DOCUMENT doc = lookups_doc_from_ptr(doc_ptr);
  FPDF_DEST dest = FPDF_GetNamedDestByName(doc, name.c_str());
  if (dest == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["found"]     = false,
        Rcpp::_["page"]      = NA_INTEGER,
        Rcpp::_["dest_view"] = NA_INTEGER,
        Rcpp::_["dest_x"]    = NA_REAL,
        Rcpp::_["dest_y"]    = NA_REAL,
        Rcpp::_["dest_zoom"] = NA_REAL);
  }
  int p = FPDFDest_GetDestPageIndex(doc, dest);
  int view = 0;
  double x = NA_REAL, y = NA_REAL, zoom = NA_REAL;
  pdfium_r::read_dest_details(doc, dest, view, x, y, zoom);
  return Rcpp::List::create(
      Rcpp::_["found"]     = true,
      Rcpp::_["page"]      = (p < 0) ? NA_INTEGER : p + 1,
      Rcpp::_["dest_view"] = view,
      Rcpp::_["dest_x"]    = x,
      Rcpp::_["dest_y"]    = y,
      Rcpp::_["dest_zoom"] = zoom);
}

// Returns the bookmark_index of the first bookmark matching `title`
// in the document's outline tree, or NA when none match. The
// matching index numbers the pre-order walk pdf_doc_bookmarks() uses.
// [[Rcpp::export(name = "cpp_bookmark_find")]]
int cpp_bookmark_find(SEXP doc_ptr, std::string title_utf8) {
  FPDF_DOCUMENT doc = lookups_doc_from_ptr(doc_ptr);
  std::vector<unsigned short> utf16 =
      pdfium_r::utf8_to_utf16le_nul(title_utf8);
  FPDF_BOOKMARK target = FPDFBookmark_Find(
      doc, reinterpret_cast<FPDF_WIDESTRING>(utf16.data()));
  if (target == nullptr) return -1;
  // Walk the outline tree in the same pre-order as
  // walk_bookmarks() to translate the FPDF_BOOKMARK handle back to
  // its 1-based bookmark_index. PDFium does not expose the index
  // directly.
  int counter = 0;
  // Iterative DFS via an explicit stack of bookmark handles to
  // visit. We push siblings right-to-left so left-most is popped
  // first (matching the recursive walker).
  std::vector<FPDF_BOOKMARK> stack;
  FPDF_BOOKMARK first = FPDFBookmark_GetFirstChild(doc, nullptr);
  if (first == nullptr) return -1;
  // Build a sibling list and push reversed.
  std::vector<FPDF_BOOKMARK> roots;
  for (FPDF_BOOKMARK b = first; b != nullptr;
       b = FPDFBookmark_GetNextSibling(doc, b)) {
    roots.push_back(b);
  }
  for (auto it = roots.rbegin(); it != roots.rend(); ++it) {
    stack.push_back(*it);
  }
  while (!stack.empty()) {
    FPDF_BOOKMARK cur = stack.back();
    stack.pop_back();
    counter++;
    if (cur == target) return counter;
    std::vector<FPDF_BOOKMARK> kids;
    for (FPDF_BOOKMARK k = FPDFBookmark_GetFirstChild(doc, cur);
         k != nullptr;
         k = FPDFBookmark_GetNextSibling(doc, k)) {
      kids.push_back(k);
    }
    for (auto it = kids.rbegin(); it != kids.rend(); ++it) {
      stack.push_back(*it);
    }
  }
  return -1;
}

// Form-field hit-test. Returns the field_type code (0..7 + XFA) at
// (x, y), or -1 when no form field is under the point. Companion
// to pdf_link_at_point().
// [[Rcpp::export(name = "cpp_form_field_at_point")]]
Rcpp::List cpp_form_field_at_point(SEXP doc_ptr, SEXP page_ptr,
                                    double x, double y) {
  FPDF_DOCUMENT doc  = lookups_doc_from_ptr(doc_ptr);
  FPDF_PAGE     page = lookups_page_from_ptr(page_ptr);
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["field_type"] = NA_INTEGER,
        Rcpp::_["z_order"]    = NA_INTEGER);
  }
  int ftype  = FPDFPage_HasFormFieldAtPoint(form, page, x, y);
  int zorder = FPDFPage_FormFieldZOrderAtPoint(form, page, x, y);
  FPDFDOC_ExitFormFillEnvironment(form);
  return Rcpp::List::create(
      Rcpp::_["field_type"] = (ftype < 0) ? NA_INTEGER : ftype,
      Rcpp::_["z_order"]    = (zorder < 0) ? NA_INTEGER : zorder);
}
