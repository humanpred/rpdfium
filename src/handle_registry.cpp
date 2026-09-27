// pdfium R package — registry of live handles. See handle_registry.h,
// ADR-024, ADR-025, ADR-028 and ADR-031.

#include <Rcpp.h>
#include <array>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_edit.h"
#include "fpdf_ppo.h"
#include "fpdf_transformpage.h"
#include "handle_registry.h"
#include "handle_validation.h"

namespace {

// Also the order in which the handles registered under one owner are
// released. Annotation contexts, pages, fonts and XObjects are
// registered under their document; documents, clip paths and bitmaps
// under the library.
enum Kind : int {
  kAnnot = 0,
  kPage,
  kFont,
  kXObject,
  kDocument,
  kClipPath,
  kBitmap,
  kKindCount
};
constexpr int kDocKindCount = kDocument;
constexpr int kLibraryKindCount = kKindCount - kDocument;

// The owner the library's handles are registered under. No document
// has a NULL address, so it cannot collide with one.
constexpr FPDF_DOCUMENT kLibrary = nullptr;

// The handles are the externalptr SEXPs themselves, held weakly:
// nothing here protects them, and the finalizer removes each one
// before R frees it (R keeps a handle until its finalizer has run).
// The reverse map finds a handle's owner without reading the handle's
// address, which is NULL once cleared.
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

void release_owned(FPDF_DOCUMENT owner) noexcept;

void close_annot(void* addr) {
  FPDFPage_CloseAnnot(static_cast<FPDF_ANNOTATION>(addr));
}
void close_page(void* addr) { FPDF_ClosePage(static_cast<FPDF_PAGE>(addr)); }
void close_font(void* addr) { FPDFFont_Close(static_cast<FPDF_FONT>(addr)); }
void close_xobject(void* addr) {
  FPDF_CloseXObject(static_cast<FPDF_XOBJECT>(addr));
}
void close_document(void* addr) {
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(addr);
  release_owned(doc);
  FPDF_CloseDocument(doc);
}
void close_clip_path(void* addr) {
  FPDF_DestroyClipPath(static_cast<FPDF_CLIPPATH>(addr));
}
void close_bitmap(void* addr) {
  FPDFBitmap_Destroy(static_cast<FPDF_BITMAP>(addr));
}

using CloseFn = void (*)(void*);
const std::array<CloseFn, kKindCount> kClose = {
    close_annot,    close_page,      close_font,  close_xobject,
    close_document, close_clip_path, close_bitmap};

void release(SEXP ptr, Kind kind) noexcept {
  if (TYPEOF(ptr) != EXTPTRSXP) return;
  forget(ptr);
  void* addr = R_ExternalPtrAddr(ptr);
  if (addr == nullptr) return;
  kClose[kind](addr);
  R_ClearExternalPtr(ptr);
}

// Release the handles registered under `owner`, a document or the
// library, kind by kind in Kind order.
void release_owned(FPDF_DOCUMENT owner) noexcept {
  auto node = g_handles.extract(owner);
  if (node.empty()) return;
  for (int kind = 0; kind < kKindCount; ++kind) {
    for (SEXP ptr : node.mapped()[kind]) {
      release(ptr, static_cast<Kind>(kind));
    }
  }
}

// The finalizer every handle carries: finalize_handle() in
// R/finalizer.R, which .onLoad passes to cpp_set_handle_finalizer().
// It is an R function, not a C one, because R keeps a C finalizer's
// address after the package's shared library is unloaded, and calls
// it (ADR-031).
SEXP g_finalizer = R_NilValue;

SEXP make_handle(void* addr, SEXP prot, FPDF_DOCUMENT owner, Kind kind) {
  if (g_finalizer == R_NilValue) {
    // # nocov start — .onLoad sets the finalizer before anything can
    // make a handle, and .onUnload clears it only after the library,
    // and every handle with it, is released.
    kClose[kind](addr);
    Rcpp::stop("pdfium's handle finalizer is not set; reload pdfium.");
    // # nocov end
  }
  SEXP ptr = PROTECT(R_MakeExternalPtr(addr, R_NilValue, prot));
  R_RegisterFinalizerEx(ptr, g_finalizer, static_cast<Rboolean>(TRUE));
  try {
    track(owner, kind, ptr);
  } catch (...) {
    // # nocov start — std::bad_alloc. An untracked handle would
    // survive its owner's release, so release it now, while the
    // owner is known to be open.
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

// The number of handles of kinds [first, first + n) registered under
// `owner`.
std::vector<int> count_owned(FPDF_DOCUMENT owner, int first, int n) {
  std::vector<int> out(n, 0);
  auto it = g_handles.find(owner);
  if (it == g_handles.end()) return out;
  for (int i = 0; i < n; ++i) {
    out[i] = static_cast<int>(it->second[first + i].size());
  }
  return out;
}

}  // namespace

namespace pdfium_r {

SEXP make_document_handle(FPDF_DOCUMENT doc, SEXP prot) {
  return make_handle(doc, prot, kLibrary, kDocument);
}

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

SEXP make_clip_path_handle(FPDF_CLIPPATH clip_path) {
  return make_handle(clip_path, R_NilValue, kLibrary, kClipPath);
}

SEXP make_bitmap_handle(FPDF_BITMAP bitmap) {
  return make_handle(bitmap, R_NilValue, kLibrary, kBitmap);
}

void release_document_handle(SEXP doc_ptr) noexcept {
  release(doc_ptr, kDocument);
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

void release_clip_path_handle(SEXP clip_path_ptr) noexcept {
  release(clip_path_ptr, kClipPath);
}

void release_bitmap_handle(SEXP bitmap_ptr) noexcept {
  release(bitmap_ptr, kBitmap);
}

void release_library_handles() noexcept { release_owned(kLibrary); }

std::vector<int> count_doc_handles(FPDF_DOCUMENT doc) {
  // A closed document's address reads as NULL, which is the library's
  // key; it has no handles of its own.
  if (doc == kLibrary) return std::vector<int>(kDocKindCount, 0);
  return count_owned(doc, 0, kDocKindCount);
}

std::vector<int> count_library_handles() {
  return count_owned(kLibrary, kDocument, kLibraryKindCount);
}

}  // namespace pdfium_r

// Set the finalizer make_handle() attaches: finalize_handle() from
// .onLoad, NULL from .onUnload. The function is preserved while set.
// [[Rcpp::export(name = "cpp_set_handle_finalizer", rng = false)]]
void cpp_set_handle_finalizer(SEXP fun) {
  if (fun != R_NilValue && TYPEOF(fun) != CLOSXP) {
    Rcpp::stop("The handle finalizer must be a function or NULL.");
  }
  if (fun != R_NilValue) R_PreserveObject(fun);
  if (g_finalizer != R_NilValue) R_ReleaseObject(g_finalizer);
  g_finalizer = fun;
}

// The native half of finalize_handle(). A handle this copy of the
// shared library registered is released. Any other handle is left
// alone: it was released already, or an earlier copy, unloaded since,
// made it, and whatever it points to belongs to that copy's PDFium.
// Without rng = false the export would read and write .Random.seed,
// which a finalizer must not do.
// [[Rcpp::export(name = "cpp_finalize_handle", rng = false)]]
void cpp_finalize_handle(SEXP ptr) {
  auto it = g_owner_of.find(ptr);
  if (it == g_owner_of.end()) return;
  release(ptr, it->second.kind);
}

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

// Test hook: the handles registered under the library, per kind.
// [[Rcpp::export(name = "cpp_library_handle_counts")]]
Rcpp::IntegerVector cpp_library_handle_counts() {
  Rcpp::IntegerVector out =
      Rcpp::wrap(pdfium_r::count_library_handles());
  out.names() =
      Rcpp::CharacterVector::create("document", "clip_path", "bitmap");
  return out;
}
