// pdfium R package — per-document registry of live handles. See
// handle_registry.h, ADR-024 and ADR-025.

#include <Rcpp.h>
#include <array>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_edit.h"
#include "fpdf_ppo.h"
#include "handle_registry.h"
#include "handle_validation.h"

namespace {

// Also the order in which release_doc_handles() closes the kinds.
enum Kind : int { kAnnot = 0, kPage, kFont, kXObject, kKindCount };

// The handles are the externalptr SEXPs themselves, held weakly:
// nothing here protects them, and the finalizer removes each one
// before R frees it. The reverse map finds a handle's document
// without reading the handle's address, which is NULL once cleared.
struct Owner {
  FPDF_DOCUMENT doc;
  Kind kind;
};
using KindSets = std::array<std::unordered_set<SEXP>, kKindCount>;
std::unordered_map<FPDF_DOCUMENT, KindSets> g_handles;
std::unordered_map<SEXP, Owner> g_owner_of;

void track(FPDF_DOCUMENT doc, Kind kind, SEXP ptr) {
  g_owner_of[ptr] = Owner{doc, kind};
  g_handles[doc][kind].insert(ptr);
}

void forget(SEXP ptr) noexcept {
  auto it = g_owner_of.find(ptr);
  if (it == g_owner_of.end()) return;
  auto doc_it = g_handles.find(it->second.doc);
  if (doc_it != g_handles.end()) {
    KindSets& sets = doc_it->second;
    sets[it->second.kind].erase(ptr);
    bool empty = true;
    for (const auto& set : sets) empty = empty && set.empty();
    if (empty) g_handles.erase(doc_it);
  }
  g_owner_of.erase(it);
}

void close_annot(void* addr) {
  FPDFPage_CloseAnnot(static_cast<FPDF_ANNOTATION>(addr));
}
void close_page(void* addr) { FPDF_ClosePage(static_cast<FPDF_PAGE>(addr)); }
void close_font(void* addr) { FPDFFont_Close(static_cast<FPDF_FONT>(addr)); }
void close_xobject(void* addr) {
  FPDF_CloseXObject(static_cast<FPDF_XOBJECT>(addr));
}

using CloseFn = void (*)(void*);
const std::array<CloseFn, kKindCount> kClose = {
    close_annot, close_page, close_font, close_xobject};

void release(SEXP ptr, Kind kind) noexcept {
  if (TYPEOF(ptr) != EXTPTRSXP) return;
  forget(ptr);
  void* addr = R_ExternalPtrAddr(ptr);
  if (addr == nullptr) return;
  kClose[kind](addr);
  R_ClearExternalPtr(ptr);
}

void finalize_annot(SEXP ptr) { release(ptr, kAnnot); }
void finalize_page(SEXP ptr) { release(ptr, kPage); }
void finalize_font(SEXP ptr) { release(ptr, kFont); }
void finalize_xobject(SEXP ptr) { release(ptr, kXObject); }

const std::array<R_CFinalizer_t, kKindCount> kFinalize = {
    finalize_annot, finalize_page, finalize_font, finalize_xobject};

SEXP make_handle(void* addr, SEXP prot, FPDF_DOCUMENT doc, Kind kind) {
  SEXP ptr = PROTECT(R_MakeExternalPtr(addr, R_NilValue, prot));
  R_RegisterCFinalizerEx(ptr, kFinalize[kind],
                         static_cast<Rboolean>(TRUE));
  try {
    track(doc, kind, ptr);
  } catch (...) {
    // # nocov start — std::bad_alloc. An untracked handle would
    // survive its document's close, so release it now, while the
    // document is known to be open.
    release(ptr, kind);
    UNPROTECT(1);
    throw;
    // # nocov end
  }
  UNPROTECT(1);
  return ptr;
}

FPDF_DOCUMENT document_of(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

}  // namespace

namespace pdfium_r {

SEXP make_annot_handle(FPDF_ANNOTATION annot, SEXP page_ptr,
                       FPDF_DOCUMENT doc) {
  return make_handle(annot, page_ptr, doc, kAnnot);
}

SEXP make_page_handle(FPDF_PAGE page, SEXP doc_ptr) {
  return make_handle(page, doc_ptr, document_of(doc_ptr), kPage);
}

SEXP make_font_handle(FPDF_FONT font, SEXP doc_ptr) {
  return make_handle(font, doc_ptr, document_of(doc_ptr), kFont);
}

SEXP make_xobject_handle(FPDF_XOBJECT xobject, SEXP doc_ptr) {
  return make_handle(xobject, doc_ptr, document_of(doc_ptr), kXObject);
}

void release_annot_handle(SEXP annot_ptr) noexcept {
  release(annot_ptr, kAnnot);
}

void release_page_handle(SEXP page_ptr) noexcept {
  release(page_ptr, kPage);
}

void release_font_handle(SEXP font_ptr) noexcept {
  release(font_ptr, kFont);
}

void release_xobject_handle(SEXP xobject_ptr) noexcept {
  release(xobject_ptr, kXObject);
}

void release_doc_handles(FPDF_DOCUMENT doc) noexcept {
  auto node = g_handles.extract(doc);
  if (node.empty()) return;
  for (int kind = 0; kind < kKindCount; ++kind) {
    for (SEXP ptr : node.mapped()[kind]) {
      release(ptr, static_cast<Kind>(kind));
    }
  }
}

std::vector<int> count_doc_handles(FPDF_DOCUMENT doc) {
  std::vector<int> out(kKindCount, 0);
  auto it = g_handles.find(doc);
  if (it == g_handles.end()) return out;
  for (int kind = 0; kind < kKindCount; ++kind) {
    out[kind] = static_cast<int>(it->second[kind].size());
  }
  return out;
}

}  // namespace pdfium_r

// Test hook: the handles registered under a document, per kind. A
// closed document has none.
// [[Rcpp::export(name = "cpp_doc_handle_counts")]]
Rcpp::IntegerVector cpp_doc_handle_counts(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  Rcpp::IntegerVector out =
      Rcpp::wrap(pdfium_r::count_doc_handles(doc));
  out.names() =
      Rcpp::CharacterVector::create("annot", "page", "font", "xobject");
  return out;
}
