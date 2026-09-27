// pdfium R package — per-document registry of live annotation
// handles. See annot_registry.h and ADR-024.

#include <Rcpp.h>
#include <unordered_map>
#include <unordered_set>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "annot_registry.h"

namespace {

// The handles are the externalptr SEXPs themselves, held weakly:
// nothing here protects them, and the finalizer removes each one
// before R frees it. The reverse map finds a handle's document
// without reading the handle's address, which is NULL once cleared.
std::unordered_map<FPDF_DOCUMENT, std::unordered_set<SEXP>> g_handles;
std::unordered_map<SEXP, FPDF_DOCUMENT> g_document_of;

void track(FPDF_DOCUMENT doc, SEXP annot_ptr) {
  g_document_of[annot_ptr] = doc;
  g_handles[doc].insert(annot_ptr);
}

void forget(SEXP annot_ptr) noexcept {
  auto it = g_document_of.find(annot_ptr);
  if (it == g_document_of.end()) return;
  auto doc_it = g_handles.find(it->second);
  if (doc_it != g_handles.end()) {
    doc_it->second.erase(annot_ptr);
    if (doc_it->second.empty()) g_handles.erase(doc_it);
  }
  g_document_of.erase(it);
}

void finalize_annot(SEXP annot_ptr) {
  pdfium_r::release_annot_handle(annot_ptr);
}

}  // namespace

namespace pdfium_r {

SEXP make_annot_handle(FPDF_ANNOTATION annot, SEXP page_ptr,
                       FPDF_DOCUMENT doc) {
  SEXP ptr = PROTECT(R_MakeExternalPtr(annot, R_NilValue, page_ptr));
  R_RegisterCFinalizerEx(ptr, finalize_annot,
                         static_cast<Rboolean>(TRUE));
  try {
    track(doc, ptr);
  } catch (...) {
    // # nocov start — std::bad_alloc. An untracked handle would
    // survive its document's close, so close the context now, while
    // the document is known to be open.
    release_annot_handle(ptr);
    UNPROTECT(1);
    throw;
    // # nocov end
  }
  UNPROTECT(1);
  return ptr;
}

void release_annot_handle(SEXP annot_ptr) noexcept {
  if (TYPEOF(annot_ptr) != EXTPTRSXP) return;
  forget(annot_ptr);
  FPDF_ANNOTATION annot =
      static_cast<FPDF_ANNOTATION>(R_ExternalPtrAddr(annot_ptr));
  if (annot == nullptr) return;
  FPDFPage_CloseAnnot(annot);
  R_ClearExternalPtr(annot_ptr);
}

void release_doc_annot_handles(FPDF_DOCUMENT doc) noexcept {
  auto node = g_handles.extract(doc);
  if (node.empty()) return;
  for (SEXP annot_ptr : node.mapped()) {
    release_annot_handle(annot_ptr);
  }
}

}  // namespace pdfium_r
