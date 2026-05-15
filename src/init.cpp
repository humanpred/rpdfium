// pdfium R package — toolchain smoke-test layer.
//
// Wires PDFium library init/destroy and exposes the minimal set of Rcpp
// functions needed by R/document.R: open document, close document, count
// pages, validity check. Later phases extend this file (or add siblings
// document.cpp, page.cpp, paths.cpp, etc.) without disturbing the lifetime
// plumbing here.

#include <Rcpp.h>
#include "fpdfview.h"

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
