// pdfium R package — form-field handle enumeration.
//
// Companion to src/form_fields.cpp's bulk reader. Where the bulk
// reader returns one big table, this file returns lists of live
// FPDF_PAGE and FPDF_ANNOTATION externalptrs that the R-side
// pdfium_form_field handles wrap.
//
// Lifetime contract:
//   * Each page that carries at least one widget annotation gets
//     ONE page handle from make_page_handle() (handle_registry.h),
//     registered under `doc` and pinning `doc_ptr` in its `prot`
//     slot, like a page from cpp_load_page.
//   * Each widget annotation gets ONE annotation handle from
//     make_annot_handle(), registered under `doc`. The annot
//     externalptr pins its parent page externalptr in its `prot`
//     slot so the page outlives the annot.
//   * The returned list keeps both alive until R's GC reclaims it;
//     closing the document closes both first.
//
// The FFL env itself is opened and closed inside this call (same
// pattern as src/form_fields.cpp). A future Phase 7 will turn it
// into a cached doc-level handle (ADR-013).

#include <Rcpp.h>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_formfill.h"
#include "handle_registry.h"

namespace {

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("doc_ptr is not an externalptr.");  // # nocov  // R wrapper validates via checkmate
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) {
    Rcpp::stop("Document handle is NULL (closed?).");  // # nocov  // covered by test-defensive.R via representative shim
  }
  return doc;
}

}  // namespace

// [[Rcpp::export(name = "cpp_form_field_handles")]]
Rcpp::List cpp_form_field_handles(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);

  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) {  // # nocov start
    // No AcroForm dict — no fields. In practice
    // FPDFDOC_InitFormFillEnvironment returns a non-null handle even
    // for AcroForm-less PDFs (PDFium creates an empty env); reaching
    // this branch would require PDFium itself to fail to allocate
    // the env struct.
    return Rcpp::List::create(
        Rcpp::_["page_handles"]   = Rcpp::List(),
        Rcpp::_["page_nums"]      = Rcpp::IntegerVector(),
        Rcpp::_["annot_handles"]  = Rcpp::List(),
        Rcpp::_["annot_page_idx"] = Rcpp::IntegerVector(),
        Rcpp::_["field_types"]    = Rcpp::IntegerVector());
  }  // # nocov end

  Rcpp::List page_handles;
  std::vector<int> page_nums;
  Rcpp::List annot_handles;
  std::vector<int> annot_page_idx;
  std::vector<int> field_types;

  int n_pages = FPDF_GetPageCount(doc);
  for (int p = 0; p < n_pages; ++p) {
    FPDF_PAGE page = FPDF_LoadPage(doc, p);
    if (page == nullptr) continue;
    int n_annots = FPDFPage_GetAnnotCount(page);
    bool page_kept = false;
    int this_page_idx = 0;
    SEXP page_ptr = R_NilValue;
    for (int ai = 0; ai < n_annots; ++ai) {
      FPDF_ANNOTATION a = FPDFPage_GetAnnot(page, ai);
      if (a == nullptr) continue;
      if (FPDFAnnot_GetSubtype(a) != FPDF_ANNOT_WIDGET) {
        FPDFPage_CloseAnnot(a);
        continue;
      }
      // First widget on this page — promote the page to a kept
      // page handle.
      if (!page_kept) {
        page_ptr = pdfium_r::make_page_handle(page, doc_ptr);
        page_handles.push_back(page_ptr);
        page_nums.push_back(p + 1);
        this_page_idx = static_cast<int>(page_handles.size());
        page_kept = true;
      }
      SEXP annot_ptr = pdfium_r::make_annot_handle(a, page_ptr, doc);
      annot_handles.push_back(annot_ptr);
      annot_page_idx.push_back(this_page_idx);
      int ftype = FPDFAnnot_GetFormFieldType(form, a);
      field_types.push_back(ftype < 0 ? NA_INTEGER : ftype);
    }
    if (!page_kept) {
      // No widgets on this page — release the page handle. The
      // page externalptr was never created, so close directly.
      FPDF_ClosePage(page);
    }
  }

  FPDFDOC_ExitFormFillEnvironment(form);

  return Rcpp::List::create(
      Rcpp::_["page_handles"]   = page_handles,
      Rcpp::_["page_nums"]      = Rcpp::wrap(page_nums),
      Rcpp::_["annot_handles"]  = annot_handles,
      Rcpp::_["annot_page_idx"] = Rcpp::wrap(annot_page_idx),
      Rcpp::_["field_types"]    = Rcpp::wrap(field_types));
}
