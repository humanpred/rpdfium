// pdfium R package — lifetime of annotation handles (ADR-024).
//
// A pdfium_annot externalptr owns a CPDF_AnnotContext, which
// FPDFPage_CloseAnnot frees together with the page-objects of the
// annotation's appearance stream. The package closes every context
// before its document: each live annotation handle is registered
// under its FPDF_DOCUMENT, and closing a document releases the
// handles registered under it first (document_handle.h).
//
// make_annot_handle() is the only way to create an annotation
// externalptr, and release_annot_handle() the only way to clear one:
// the finalizer, pdf_annot_delete() and document close all go
// through it, so the registry never holds a handle R has freed.

#ifndef PDFIUM_R_PKG_ANNOT_REGISTRY_H
#define PDFIUM_R_PKG_ANNOT_REGISTRY_H

#include <Rcpp.h>
#include "fpdfview.h"

namespace pdfium_r {

// Wrap `annot` in an externalptr that pins `page_ptr` in its prot
// slot, carries the annotation finalizer, and is registered under
// `doc`. `doc` must be the open document that `page_ptr`'s page
// belongs to.
SEXP make_annot_handle(FPDF_ANNOTATION annot, SEXP page_ptr,
                       FPDF_DOCUMENT doc);

// Forget `annot_ptr`, then close its context and clear it. Only the
// forgetting happens when the handle is already cleared.
void release_annot_handle(SEXP annot_ptr) noexcept;

// Release every handle registered under `doc`. Must run before
// FPDF_CloseDocument(doc).
void release_doc_annot_handles(FPDF_DOCUMENT doc) noexcept;

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_ANNOT_REGISTRY_H
