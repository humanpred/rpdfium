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

// Read one structure-element attribute *value* as a typed R SEXP.
// PDFium's value tagging is the same enum as page-object marks:
// BOOLEAN / NUMBER / STRING / NAME / others -> NULL.
SEXP read_attr_value(FPDF_STRUCTELEMENT_ATTR_VALUE value) {
  if (value == nullptr) return R_NilValue;
  int type = FPDF_StructElement_Attr_GetType(value);
  if (type == FPDF_OBJECT_BOOLEAN) {
    FPDF_BOOL b = 0;
    if (FPDF_StructElement_Attr_GetBooleanValue(value, &b)) {
      return Rcpp::wrap(static_cast<bool>(b));
    }
    return Rcpp::wrap(NA_LOGICAL);
  }
  if (type == FPDF_OBJECT_NUMBER) {
    float f = 0.f;
    if (FPDF_StructElement_Attr_GetNumberValue(value, &f)) {
      return Rcpp::wrap(static_cast<double>(f));
    }
    return Rcpp::wrap(NA_REAL);
  }
  if (type == FPDF_OBJECT_STRING || type == FPDF_OBJECT_NAME) {
    unsigned long out_buflen = 0;
    if (!FPDF_StructElement_Attr_GetStringValue(value, nullptr, 0,
                                                  &out_buflen)) {
      return Rcpp::wrap(NA_STRING);
    }
    if (out_buflen <= 2) return Rcpp::wrap(std::string());
    std::vector<char> buf(out_buflen);
    if (!FPDF_StructElement_Attr_GetStringValue(value, buf.data(),
                                                  out_buflen,
                                                  &out_buflen)) {
      return Rcpp::wrap(NA_STRING);
    }
    return Rcpp::wrap(std::string(buf.data(), out_buflen - 1));
  }
  // Blob: surface as raw vector. Other types (Array / Dict /
  // Reference) come back as NULL — PDFium doesn't expose them via
  // this API.
  unsigned long out_buflen = 0;
  if (FPDF_StructElement_Attr_GetBlobValue(value, nullptr, 0,
                                            &out_buflen)) {
    if (out_buflen == 0) return Rcpp::RawVector(0);
    Rcpp::RawVector blob(static_cast<R_xlen_t>(out_buflen));
    if (FPDF_StructElement_Attr_GetBlobValue(value, RAW(blob),
                                              out_buflen, &out_buflen)) {
      return blob;
    }
  }
  return R_NilValue;
}

// Aggregate all attributes from a structure element into one named
// list. Each attribute *object* on the element contributes its own
// (name, value) pairs; we concatenate across attribute objects so
// callers see a single flat namespace. Duplicate keys are kept as
// the last-write-wins value (PDFium does not normalise attribute
// objects on the read side).
SEXP read_struct_attributes(FPDF_STRUCTELEMENT element) {
  int n_attrs = FPDF_StructElement_GetAttributeCount(element);
  if (n_attrs <= 0) return Rcpp::List();
  std::vector<std::string> all_keys;
  std::vector<SEXP> all_vals;
  for (int a = 0; a < n_attrs; ++a) {
    FPDF_STRUCTELEMENT_ATTR attr =
        FPDF_StructElement_GetAttributeAtIndex(element, a);
    if (attr == nullptr) continue;
    int n_keys = FPDF_StructElement_Attr_GetCount(attr);
    if (n_keys <= 0) continue;
    for (int k = 0; k < n_keys; ++k) {
      // First pass: probe key length.
      unsigned long key_buflen = 0;
      if (!FPDF_StructElement_Attr_GetName(attr, k, nullptr, 0,
                                             &key_buflen)) {
        continue;
      }
      if (key_buflen <= 1) continue;
      std::vector<char> key_buf(key_buflen);
      if (!FPDF_StructElement_Attr_GetName(attr, k, key_buf.data(),
                                             key_buflen,
                                             &key_buflen)) {
        continue;
      }
      std::string key(key_buf.data(), key_buflen - 1);
      FPDF_STRUCTELEMENT_ATTR_VALUE val =
          FPDF_StructElement_Attr_GetValue(attr, key.c_str());
      all_keys.push_back(key);
      all_vals.push_back(read_attr_value(val));
    }
  }
  Rcpp::List out(all_keys.size());
  Rcpp::CharacterVector names(all_keys.size());
  for (size_t i = 0; i < all_keys.size(); ++i) {
    names[i] = all_keys[i];
    out[i]   = all_vals[i];
  }
  out.attr("names") = names;
  return out;
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
                 std::vector<std::string>& obj_types,
                 std::vector<std::string>& titles,
                 std::vector<std::string>& langs,
                 std::vector<std::string>& alt_texts,
                 std::vector<std::string>& actual_texts,
                 std::vector<std::string>& ids,
                 std::vector<int>& mcids,
                 std::vector<int>& mcid_counts,
                 Rcpp::List& attributes) {
  if (element == nullptr) return;
  parent_indices.push_back(parent_index);
  levels.push_back(level);
  types.push_back(read_struct_string(element, FPDF_StructElement_GetType));
  obj_types.push_back(
      read_struct_string(element, FPDF_StructElement_GetObjType));
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
  attributes.push_back(read_struct_attributes(element));

  int this_index = static_cast<int>(parent_indices.size());
  int n_children = FPDF_StructElement_CountChildren(element);
  for (int i = 0; i < n_children; ++i) {
    FPDF_STRUCTELEMENT child =
        FPDF_StructElement_GetChildAtIndex(element, i);
    walk_struct(child, this_index, level + 1,
                parent_indices, levels, types, obj_types, titles,
                langs, alt_texts, actual_texts, ids, mcids,
                mcid_counts, attributes);
  }
}

}  // namespace

// [[Rcpp::export(name = "cpp_struct_tree_page")]]
Rcpp::List cpp_struct_tree_page(SEXP page_ptr) {
  FPDF_PAGE page = struct_page_from_ptr(page_ptr);

  std::vector<int> parent_indices;
  std::vector<int> levels;
  std::vector<std::string> types;
  std::vector<std::string> obj_types;
  std::vector<std::string> titles;
  std::vector<std::string> langs;
  std::vector<std::string> alt_texts;
  std::vector<std::string> actual_texts;
  std::vector<std::string> ids;
  std::vector<int> mcids;
  std::vector<int> mcid_counts;
  Rcpp::List attributes;

  FPDF_STRUCTTREE tree = FPDF_StructTree_GetForPage(page);
  if (tree != nullptr) {
    int n = FPDF_StructTree_CountChildren(tree);
    for (int i = 0; i < n; ++i) {
      FPDF_STRUCTELEMENT root_child =
          FPDF_StructTree_GetChildAtIndex(tree, i);
      walk_struct(root_child, /*parent=*/0, /*level=*/1,
                  parent_indices, levels, types, obj_types, titles,
                  langs, alt_texts, actual_texts, ids, mcids,
                  mcid_counts, attributes);
    }
    FPDF_StructTree_Close(tree);
  }

  return Rcpp::List::create(
      Rcpp::_["parent_index"] = parent_indices,
      Rcpp::_["level"]        = levels,
      Rcpp::_["type"]         = types,
      Rcpp::_["obj_type"]     = obj_types,
      Rcpp::_["title"]        = titles,
      Rcpp::_["lang"]         = langs,
      Rcpp::_["alt_text"]     = alt_texts,
      Rcpp::_["actual_text"]  = actual_texts,
      Rcpp::_["id"]           = ids,
      Rcpp::_["mcid"]         = mcids,
      Rcpp::_["mcid_count"]   = mcid_counts,
      Rcpp::_["attributes"]   = attributes);
}
