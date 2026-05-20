// pdfium R package — toolchain smoke-test layer.
//
// Wires PDFium library init/destroy and exposes the minimal set of Rcpp
// functions needed by R/document.R: open document, close document, count
// pages, validity check. Later phases extend this file (or add siblings
// document.cpp, page.cpp, paths.cpp, etc.) without disturbing the lifetime
// plumbing here.

#include <Rcpp.h>
#include <cstring>
#include "fpdfview.h"
#include "fpdf_edit.h"

namespace {

// Tracks whether FPDF_InitLibraryWithConfig() has been called. The .onLoad
// hook in R/zzz.R calls cpp_init_library(); .onUnload calls
// cpp_destroy_library(). Idempotency lets tests force re-init without
// crashing PDFium.
bool g_library_initialised = false;

void finalize_document(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) return;
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(ptr));
  if (doc != nullptr) {
    FPDF_CloseDocument(doc);
    R_ClearExternalPtr(ptr);
  }
}

} // namespace

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

// [[Rcpp::export(name = "cpp_destroy_library")]]
void cpp_destroy_library() {
  if (!g_library_initialised) return;
  FPDF_DestroyLibrary();
  g_library_initialised = false;
}

// [[Rcpp::export(name = "cpp_open_document")]]
SEXP cpp_open_document(std::string path, std::string password) {
  if (!g_library_initialised) cpp_init_library();
  const char* pwd = password.empty() ? nullptr : password.c_str();
  FPDF_DOCUMENT doc = FPDF_LoadDocument(path.c_str(), pwd);
  if (doc == nullptr) {
    unsigned long err = FPDF_GetLastError();
    Rcpp::stop("Failed to load PDF (FPDF error %lu): %s", err, path);
  }
  SEXP ptr = PROTECT(R_MakeExternalPtr(doc, R_NilValue, R_NilValue));
  // Explicit Rboolean cast: PDFium's public headers transitively include
  // <windows.h> on Windows, which defines TRUE as the integer macro 1.
  // Under -Werror=permissive that conversion to Rboolean fails to compile;
  // the cast keeps the source portable across Linux / macOS / Windows.
  R_RegisterCFinalizerEx(ptr, finalize_document, static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ptr;
}

// [[Rcpp::export(name = "cpp_open_document_from_memory")]]
SEXP cpp_open_document_from_memory(Rcpp::RawVector bytes,
                                   std::string password) {
  if (!g_library_initialised) cpp_init_library();
  const char* pwd = password.empty() ? nullptr : password.c_str();
  // FPDF_LoadMemDocument64 takes a 64-bit size so R xlen_t values
  // beyond INT_MAX are safe. The buffer must remain valid for the
  // lifetime of the FPDF_DOCUMENT (PDFium does not copy it), so we
  // copy the R RAW vector into a heap buffer owned by the document
  // and free it in the finalizer via the externalptr's `tag` slot.
  size_t n = static_cast<size_t>(bytes.size());
  unsigned char* buf = new unsigned char[n];
  std::memcpy(buf, bytes.begin(), n);
  FPDF_DOCUMENT doc =
      FPDF_LoadMemDocument64(buf, n, pwd);
  if (doc == nullptr) {
    delete[] buf;
    unsigned long err = FPDF_GetLastError();
    Rcpp::stop("Failed to load PDF from memory (FPDF error %lu).",
               err);
  }
  // Wrap the heap buffer in an externalptr so R reclaims it when
  // the document externalptr is GC'd. The buffer-finalizer cannot
  // run while the doc is live because we keep the buffer-ptr in
  // the doc-ptr's protected slot.
  SEXP buf_ptr = PROTECT(
      R_MakeExternalPtr(buf, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(buf_ptr,
                          [](SEXP p) {
                            void* b = R_ExternalPtrAddr(p);
                            if (b != nullptr) {
                              delete[] static_cast<unsigned char*>(b);
                              R_ClearExternalPtr(p);
                            }
                          },
                          static_cast<Rboolean>(TRUE));
  // doc_ptr's prot slot pins buf_ptr (so the buffer outlives the
  // doc); doc_ptr's tag slot is unused.
  SEXP doc_ptr = PROTECT(R_MakeExternalPtr(doc, R_NilValue, buf_ptr));
  R_RegisterCFinalizerEx(doc_ptr, finalize_document,
                          static_cast<Rboolean>(TRUE));
  UNPROTECT(2);
  return doc_ptr;
}

// [[Rcpp::export(name = "cpp_create_new_document")]]
SEXP cpp_create_new_document() {
  if (!g_library_initialised) cpp_init_library();
  FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
  if (doc == nullptr) {
    Rcpp::stop("FPDF_CreateNewDocument() returned NULL.");
  }
  SEXP ptr = PROTECT(R_MakeExternalPtr(doc, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(ptr, finalize_document, static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ptr;
}

// [[Rcpp::export(name = "cpp_close_document")]]
void cpp_close_document(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(ptr));
  if (doc != nullptr) {
    FPDF_CloseDocument(doc);
    R_ClearExternalPtr(ptr);
  }
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
