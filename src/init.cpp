// pdfium R package — toolchain smoke-test layer.
//
// Wires PDFium library init/destroy and exposes the minimal set of Rcpp
// functions needed by R/document.R: open document, close document, count
// pages, validity check. Later phases extend this file (or add siblings
// document.cpp, page.cpp, paths.cpp, etc.) without disturbing the lifetime
// plumbing here.

#include <Rcpp.h>
#include <algorithm>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "fpdf_sysfontinfo.h"
#include "handle_registry.h"

namespace {

// Tracks whether FPDF_InitLibraryWithConfig() has been called. The .onLoad
// hook in R/zzz.R calls cpp_init_library(); .onUnload calls
// cpp_destroy_library(). Idempotency lets tests force re-init without
// crashing PDFium.
bool g_library_initialised = false;

// The provider cpp_install_default_sysfont_info() installed into the
// current library instance, if any. The application owns it
// (fpdf_sysfontinfo.h); cpp_destroy_library() frees it.
FPDF_SYSFONTINFO* g_default_sysfont_info = nullptr;

// How many times R has loaded this image of the shared library: R runs
// R_init_pdfium() on every dyn.load(). A fresh image counts 1. An image
// that dyn.unload() left mapped counts on, statics and all: glibc keeps
// a library with a GNU-unique symbol loaded, and -O0 builds such as
// covr's emit one for std::piecewise_construct.
int g_load_generation = 0;

} // namespace

// [[Rcpp::init]]
void count_load_generation(DllInfo* /*dll*/) { ++g_load_generation; }

// Test hook: this image's load generation.
// [[Rcpp::export(name = "cpp_load_generation")]]
int cpp_load_generation() { return g_load_generation; }

// [[Rcpp::export(name = "cpp_init_library")]]
void cpp_init_library() {
  if (g_library_initialised) return;
  FPDF_LIBRARY_CONFIG cfg = {};
  cfg.version = 2;
  cfg.m_pUserFontPaths = nullptr;
  cfg.m_pIsolate = nullptr;
  cfg.m_v8EmbedderSlot = 0;
  FPDF_InitLibraryWithConfig(&cfg);
  g_library_initialised = true;
}

namespace pdfium_r {

void ensure_library_initialised() { cpp_init_library(); }

}  // namespace pdfium_r

// PDFium must not be called once the library is destroyed, and a
// document, page or other object it made is not safe to close after
// that, nor once the library is initialised again (fpdfview.h,
// ADR-028). Every such handle is registered under the library, so it
// is released first: its externalptr reads as closed from then on, and
// its finalizer has nothing left to do.
// [[Rcpp::export(name = "cpp_destroy_library")]]
void cpp_destroy_library() {
  if (!g_library_initialised) return;
  pdfium_r::release_library_handles();
  FPDF_DestroyLibrary();
  // Tearing the library down runs the installed provider's Release
  // callback, which reads the struct; only afterwards is it unused.
  if (g_default_sysfont_info != nullptr) {
    FPDF_FreeDefaultSystemFontInfo(g_default_sysfont_info);
    g_default_sysfont_info = nullptr;
  }
  g_library_initialised = false;
}

// Install PDFium's platform-default system-font provider into the
// library, once per library lifetime: while one is installed, a repeat
// call returns true without allocating another.
// [[Rcpp::export(name = "cpp_install_default_sysfont_info")]]
bool cpp_install_default_sysfont_info() {
  pdfium_r::ensure_library_initialised();
  if (g_default_sysfont_info != nullptr) return true;
  FPDF_SYSFONTINFO* info = FPDF_GetDefaultSystemFontInfo();
  // # nocov start — NULL only on platforms without a default provider
  // (fpdf_sysfontinfo.h); the bundled Linux, macOS and Windows builds
  // have one.
  if (info == nullptr) {
    return false;
  }
  // # nocov end
  FPDF_SetSystemFontInfo(info);
  g_default_sysfont_info = info;
  return true;
}

// [[Rcpp::export(name = "cpp_open_document")]]
SEXP cpp_open_document(std::string path, std::string password) {
  pdfium_r::ensure_library_initialised();
  const char* pwd = password.empty() ? nullptr : password.c_str();
  FPDF_DOCUMENT doc = FPDF_LoadDocument(path.c_str(), pwd);
  if (doc == nullptr) {
    unsigned long err = FPDF_GetLastError();
    Rcpp::stop("Failed to load PDF (FPDF error %lu): %s", err, path);
  }
  return pdfium_r::make_document_handle(doc, R_NilValue);
}

// [[Rcpp::export(name = "cpp_open_document_from_memory")]]
SEXP cpp_open_document_from_memory(Rcpp::RawVector bytes,
                                   std::string password) {
  pdfium_r::ensure_library_initialised();
  const char* pwd = password.empty() ? nullptr : password.c_str();
  // FPDF_LoadMemDocument64 takes a 64-bit size so R xlen_t values
  // beyond INT_MAX are safe. PDFium reads the buffer until the document
  // is closed, without copying it, so the document reads from a copy
  // of `bytes` that its handle pins in its prot slot. R never moves a
  // vector, nothing else can reach the copy to change it, and R frees
  // it only after the handle, so after the document is closed. The
  // copy needs no finalizer (ADR-031).
  Rcpp::RawVector buf(Rcpp::no_init(bytes.size()));
  std::copy(bytes.begin(), bytes.end(), buf.begin());
  FPDF_DOCUMENT doc = FPDF_LoadMemDocument64(
      buf.begin(), static_cast<size_t>(buf.size()), pwd);
  if (doc == nullptr) {
    unsigned long err = FPDF_GetLastError();
    Rcpp::stop("Failed to load PDF from memory (FPDF error %lu).",
               err);
  }
  return pdfium_r::make_document_handle(doc, buf);
}

// [[Rcpp::export(name = "cpp_create_new_document")]]
SEXP cpp_create_new_document() {
  pdfium_r::ensure_library_initialised();
  FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
  // # nocov start — FPDF_CreateNewDocument allocates a fresh in-memory
  // doc and only returns NULL on out-of-memory, which we don't
  // recover from in pdfium's R surface.
  if (doc == nullptr) {
    Rcpp::stop("FPDF_CreateNewDocument() returned NULL.");
  }
  // # nocov end
  return pdfium_r::make_document_handle(doc, R_NilValue);
}

// [[Rcpp::export(name = "cpp_close_document")]]
void cpp_close_document(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  pdfium_r::release_document_handle(ptr);
}

// [[Rcpp::export(name = "cpp_handle_is_valid")]]
bool cpp_handle_is_valid(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) return false;
  return R_ExternalPtrAddr(ptr) != nullptr;
}

// [[Rcpp::export(name = "cpp_page_count")]]
int cpp_page_count(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(ptr));
  if (doc == nullptr) {
    Rcpp::stop("Document handle is closed.");
  }
  return FPDF_GetPageCount(doc);
}
