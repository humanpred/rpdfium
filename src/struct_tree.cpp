// pdfium R package — tagged-PDF structure tree readout.
//
// PDF accessibility ("tagged PDF") is exposed through PDFium's
// fpdf_structtree.h surface: every page can have its own view of
// the doc-wide /StructTreeRoot, accessed via:
//
//   FPDF_StructTree_GetForPage(page)
//     FPDF_StructTree_CountChildren / GetChildAtIndex
//       FPDF_StructElement_GetType        // "/S" - "P", "H1", etc.
//       FPDF_StructElement_GetTitle       // "/T"
//       FPDF_StructElement_GetLang        // "/Lang"
//       FPDF_StructElement_GetAltText     // "/Alt"
//       FPDF_StructElement_GetActualText  // "/ActualText"
//       FPDF_StructElement_GetID          // "/ID"
//       FPDF_StructElement_GetMarkedContentID
//       FPDF_StructElement_CountChildren / GetChildAtIndex (recurse)
//   FPDF_StructTree_Close
//
// We walk the tree depth-first and produce parallel vectors that
// R folds into one tibble row per element. parent_index is 1-based
// within the walk and 0 for top-level entries; level is 1-based.

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_structtree.h"
#include "utf16.h"

namespace {

FPDF_PAGE struct_page_from_ptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

// Read a UTF-16LE string via PDFium's standard byte-counted protocol
// (NULL/0 query for size, then real call). Returns "" when absent.
std::string read_struct_string(
    FPDF_STRUCTELEMENT element,
    unsigned long (*getter)(FPDF_STRUCTELEMENT, void*, unsigned long)) {
  unsigned long need = getter(element, nullptr, 0);
  if (need <= 2) return std::string();
  std::vector<unsigned short> buf(need / 2);
  getter(element, buf.data(), need);
  size_t wchars = (need >= 2 ? need / 2 - 1 : need / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// Resolve the "primary" MCID for a structure element. PDFium splits
// the marked-content surface across two API paths:
//   * FPDF_StructElement_GetMarkedContentID returns the MCID when
//     the element is a direct /K integer reference.
//   * FPDF_StructElement_GetMarkedContentIdCount/AtIndex returns the
//     MCIDs from any MCR (Marked Content Reference) children
//     (/K << /Type /MCR /Pg ... /MCID N >>).
// We surface the first available MCID (direct preferred, then first
// MCR child) plus the total count so callers can detect elements
// that span multiple content tags.
struct StructElementMCID {
  int mcid;
  int count;
};

StructElementMCID resolve_element_mcid(FPDF_STRUCTELEMENT element) {
  StructElementMCID out{NA_INTEGER, 0};
  int direct = FPDF_StructElement_GetMarkedContentID(element);
  if (direct >= 0) {
    out.mcid = direct;
    out.count = 1;
    return out;
  }
  // GetMarkedContentIdCount counts every /K entry (including
  // sub-element references), so we have to ask
  // GetMarkedContentIdAtIndex per slot and only tally the slots
  // PDFium reports as real MCIDs. Container elements like
  // Document/Sect see real_count == 0 with this filter.
  int n = FPDF_StructElement_GetMarkedContentIdCount(element);
  for (int i = 0; i < n; ++i) {
    int id = FPDF_StructElement_GetMarkedContentIdAtIndex(element, i);
    if (id < 0) continue;
    if (out.count == 0) out.mcid = id;
    out.count++;
  }
  return out;
}

// Depth-first walk over the structure subtree rooted at `element`.
// Emits one entry per element into the parallel output vectors.
void walk_struct(FPDF_STRUCTELEMENT element,
                 int parent_index,
                 int level,
                 std::vector<int>& parent_indices,
                 std::vector<int>& levels,
                 std::vector<std::string>& types,
                 std::vector<std::string>& titles,
                 std::vector<std::string>& langs,
                 std::vector<std::string>& alt_texts,
                 std::vector<std::string>& actual_texts,
                 std::vector<std::string>& ids,
                 std::vector<int>& mcids,
                 std::vector<int>& mcid_counts) {
  if (element == nullptr) return;
  parent_indices.push_back(parent_index);
  levels.push_back(level);
  types.push_back(read_struct_string(element, FPDF_StructElement_GetType));
  titles.push_back(read_struct_string(element, FPDF_StructElement_GetTitle));
  langs.push_back(read_struct_string(element, FPDF_StructElement_GetLang));
  alt_texts.push_back(
      read_struct_string(element, FPDF_StructElement_GetAltText));
  actual_texts.push_back(
      read_struct_string(element, FPDF_StructElement_GetActualText));
  ids.push_back(read_struct_string(element, FPDF_StructElement_GetID));
  StructElementMCID m = resolve_element_mcid(element);
  mcids.push_back(m.mcid);
  mcid_counts.push_back(m.count);

  int this_index = static_cast<int>(parent_indices.size());
  int n_children = FPDF_StructElement_CountChildren(element);
  for (int i = 0; i < n_children; ++i) {
    FPDF_STRUCTELEMENT child =
        FPDF_StructElement_GetChildAtIndex(element, i);
    walk_struct(child, this_index, level + 1,
                parent_indices, levels, types, titles, langs,
                alt_texts, actual_texts, ids, mcids, mcid_counts);
  }
}

}  // namespace

// [[Rcpp::export(name = "cpp_struct_tree_page")]]
Rcpp::List cpp_struct_tree_page(SEXP page_ptr) {
  FPDF_PAGE page = struct_page_from_ptr(page_ptr);

  std::vector<int> parent_indices;
  std::vector<int> levels;
  std::vector<std::string> types;
  std::vector<std::string> titles;
  std::vector<std::string> langs;
  std::vector<std::string> alt_texts;
  std::vector<std::string> actual_texts;
  std::vector<std::string> ids;
  std::vector<int> mcids;
  std::vector<int> mcid_counts;

  FPDF_STRUCTTREE tree = FPDF_StructTree_GetForPage(page);
  if (tree != nullptr) {
    int n = FPDF_StructTree_CountChildren(tree);
    for (int i = 0; i < n; ++i) {
      FPDF_STRUCTELEMENT root_child =
          FPDF_StructTree_GetChildAtIndex(tree, i);
      walk_struct(root_child, /*parent=*/0, /*level=*/1,
                  parent_indices, levels, types, titles, langs,
                  alt_texts, actual_texts, ids, mcids, mcid_counts);
    }
    FPDF_StructTree_Close(tree);
  }

  return Rcpp::List::create(
      Rcpp::_["parent_index"] = parent_indices,
      Rcpp::_["level"]        = levels,
      Rcpp::_["type"]         = types,
      Rcpp::_["title"]        = titles,
      Rcpp::_["lang"]         = langs,
      Rcpp::_["alt_text"]     = alt_texts,
      Rcpp::_["actual_text"]  = actual_texts,
      Rcpp::_["id"]           = ids,
      Rcpp::_["mcid"]         = mcids,
      Rcpp::_["mcid_count"]   = mcid_counts);
}
