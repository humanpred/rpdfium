// pdfium R package — structural mutation surface.
//
// One-liner shims around PDFium's doc/page mutators:
//
//   FPDFPage_New / _Delete / _SetRotation
//   FPDF_MovePages
//   FPDF_ImportPagesByIndex (pdf_docs_merge backbone)
//   FPDFPage_Set{Media,Crop,Bleed,Trim,Art}Box
//   FPDFCatalog_SetLanguage
//   FPDFPage_GenerateContent (run on a page before save to persist edits)
//
// Each takes the bare externalptr; the R wrapper handles validation
// and the doc$readwrite check.

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "fpdf_catalog.h"
#include "fpdf_ppo.h"
#include "fpdf_transformpage.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT doc_from_xptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("doc_ptr is not an externalptr.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) {
    Rcpp::stop("Document handle is NULL (closed?).");
  }
  return doc;
}

FPDF_PAGE page_from_xptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("page_ptr is not an externalptr.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) {
    Rcpp::stop("Page handle is NULL (closed?).");
  }
  return page;
}

void finalize_new_page(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) return;
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(ptr));
  if (page != nullptr) {
    FPDF_ClosePage(page);
    R_ClearExternalPtr(ptr);
  }
}

} // namespace

// [[Rcpp::export(name = "cpp_page_new")]]
SEXP cpp_page_new(SEXP doc_ptr, int page_index, double width,
                  double height) {
  FPDF_DOCUMENT doc = doc_from_xptr(doc_ptr);
  FPDF_PAGE page = FPDFPage_New(doc, page_index, width, height);
  // # nocov start — FPDFPage_New only returns NULL when the doc
  // pointer is invalid, which the R wrapper prevents via
  // assert_readwrite() + cpp_page_count() before calling here.
  if (page == nullptr) {
    Rcpp::stop("FPDFPage_New failed.");
  }
  // # nocov end
  SEXP ptr = PROTECT(R_MakeExternalPtr(page, R_NilValue, doc_ptr));
  R_RegisterCFinalizerEx(ptr, finalize_new_page,
                         static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ptr;
}

// [[Rcpp::export(name = "cpp_page_delete")]]
void cpp_page_delete(SEXP doc_ptr, int page_index) {
  FPDF_DOCUMENT doc = doc_from_xptr(doc_ptr);
  FPDFPage_Delete(doc, page_index);
}

// [[Rcpp::export(name = "cpp_page_set_rotation")]]
void cpp_page_set_rotation(SEXP page_ptr, int rotation_code) {
  FPDF_PAGE page = page_from_xptr(page_ptr);
  FPDFPage_SetRotation(page, rotation_code);
}

// [[Rcpp::export(name = "cpp_move_pages")]]
bool cpp_move_pages(SEXP doc_ptr, Rcpp::IntegerVector page_indices,
                    int dest_index) {
  FPDF_DOCUMENT doc = doc_from_xptr(doc_ptr);
  std::vector<int> idx(page_indices.begin(), page_indices.end());
  return FPDF_MovePages(doc, idx.data(),
                        static_cast<unsigned long>(idx.size()),
                        dest_index) != 0;
}

// [[Rcpp::export(name = "cpp_import_pages_by_index")]]
bool cpp_import_pages_by_index(SEXP dest_doc_ptr, SEXP src_doc_ptr,
                               Rcpp::IntegerVector page_indices,
                               int insert_index) {
  FPDF_DOCUMENT dest = doc_from_xptr(dest_doc_ptr);
  FPDF_DOCUMENT src  = doc_from_xptr(src_doc_ptr);
  std::vector<int> idx(page_indices.begin(), page_indices.end());
  return FPDF_ImportPagesByIndex(dest, src, idx.data(),
                                 static_cast<unsigned long>(idx.size()),
                                 insert_index) != 0;
}

// [[Rcpp::export(name = "cpp_import_n_pages_to_one")]]
SEXP cpp_import_n_pages_to_one(SEXP src_doc_ptr,
                               float output_width, float output_height,
                               int n_cols, int n_rows) {
  FPDF_DOCUMENT src = doc_from_xptr(src_doc_ptr);
  FPDF_DOCUMENT out = FPDF_ImportNPagesToOne(
      src, output_width, output_height,
      static_cast<size_t>(n_cols), static_cast<size_t>(n_rows));
  // # nocov start — FPDF_ImportNPagesToOne returns NULL only for
  // pathological inputs (zero cols/rows, NULL doc) which the R
  // wrapper checks via checkmate::assert_count() upstream.
  if (out == nullptr) {
    Rcpp::stop("FPDF_ImportNPagesToOne failed.");
  }
  // # nocov end
  SEXP ptr = PROTECT(R_MakeExternalPtr(out, R_NilValue, R_NilValue));
  // Reuse the document finalizer by registering one inline. Mirrors
  // init.cpp's finalize_document.
  R_RegisterCFinalizerEx(
      ptr,
      [](SEXP p) {
        if (TYPEOF(p) != EXTPTRSXP) return;
        FPDF_DOCUMENT d =
            static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(p));
        if (d != nullptr) {
          FPDF_CloseDocument(d);
          R_ClearExternalPtr(p);
        }
      },
      static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ptr;
}

// [[Rcpp::export(name = "cpp_page_set_box")]]
void cpp_page_set_box(SEXP page_ptr, std::string box,
                      float left, float bottom,
                      float right, float top) {
  FPDF_PAGE page = page_from_xptr(page_ptr);
  if      (box == "media") FPDFPage_SetMediaBox(page, left, bottom, right, top);
  else if (box == "crop")  FPDFPage_SetCropBox(page, left, bottom, right, top);
  else if (box == "bleed") FPDFPage_SetBleedBox(page, left, bottom, right, top);
  else if (box == "trim")  FPDFPage_SetTrimBox(page, left, bottom, right, top);
  else if (box == "art")   FPDFPage_SetArtBox(page, left, bottom, right, top);
  else Rcpp::stop("Unknown box `%s`.", box.c_str());
}

// [[Rcpp::export(name = "cpp_catalog_set_language")]]
bool cpp_catalog_set_language(SEXP doc_ptr, std::string lang) {
  // FPDFCatalog_SetLanguage takes an FPDF_WIDESTRING (UTF-16LE, NUL-
  // terminated) as of PDFium chromium/7857; earlier releases declared
  // it as a UTF-8 FPDF_BYTESTRING. The R-side wrapper passes
  // `enc2utf8(lang)`, so the bytes are canonical UTF-8 going in; we
  // transcode to UTF-16LE here.
  FPDF_DOCUMENT doc = doc_from_xptr(doc_ptr);
  std::vector<unsigned short> lang16 = pdfium_r::utf8_to_utf16le_nul(lang);
  return FPDFCatalog_SetLanguage(
             doc, reinterpret_cast<FPDF_WIDESTRING>(lang16.data())) != 0;
}

// [[Rcpp::export(name = "cpp_catalog_get_language")]]
SEXP cpp_catalog_get_language(SEXP doc_ptr) {
  // Reader half of FPDFCatalog_SetLanguage, added in PDFium
  // chromium/7857. Same byte-counted UTF-16LE protocol as
  // FPDF_GetMetaText: a NULL/0 sizing call returns the byte count
  // (including the trailing NUL), then the real call fills the buffer.
  // An absent /Lang entry returns 2 (just the NUL); an error returns 0
  // — both decode to "".
  FPDF_DOCUMENT doc = doc_from_xptr(doc_ptr);
  unsigned long n_bytes = FPDFCatalog_GetLanguage(doc, nullptr, 0UL);
  std::string lang;
  if (n_bytes > 2) {
    size_t n_wchars = n_bytes / 2;
    std::vector<unsigned short> buf(n_wchars);
    FPDFCatalog_GetLanguage(doc, buf.data(), n_bytes);
    lang = pdfium_r::utf16le_to_utf8(buf.data(), n_wchars - 1);
  }
  SEXP r_chr = PROTECT(Rf_mkCharLenCE(
      lang.data(), static_cast<int>(lang.size()), CE_UTF8));
  SEXP r_vec = PROTECT(Rf_allocVector(STRSXP, 1));
  SET_STRING_ELT(r_vec, 0, r_chr);
  UNPROTECT(2);
  return r_vec;
}

// [[Rcpp::export(name = "cpp_page_generate_content")]]
bool cpp_page_generate_content(SEXP page_ptr) {
  FPDF_PAGE page = page_from_xptr(page_ptr);
  return FPDFPage_GenerateContent(page) != 0;
}
