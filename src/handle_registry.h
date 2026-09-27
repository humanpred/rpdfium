// pdfium R package — lifetime of document-owned handles (ADR-024,
// ADR-025).
//
// PDFium expects every page, annotation context, font and XObject to
// be closed before the document it belongs to. The package keeps that
// order in every teardown: each live handle of these kinds is
// registered under its FPDF_DOCUMENT, and closing a document releases
// the handles registered under it first (document_handle.h).
//
// For each kind, make_*_handle() is the only way to create the
// externalptr and release_*_handle() the only way to clear it: the
// finalizer, the explicit close (pdf_page_close(), pdf_font_close(),
// pdf_xobject_close(), pdf_annot_delete()) and document close all go
// through it, so the registry never holds a handle R has freed.

#ifndef PDFIUM_R_PKG_HANDLE_REGISTRY_H
#define PDFIUM_R_PKG_HANDLE_REGISTRY_H

#include <Rcpp.h>
#include "fpdfview.h"

namespace pdfium_r {

// Wrap `annot` in an externalptr that pins `page_ptr` in its prot
// slot, carries the annotation finalizer, and is registered under
// `doc`. `doc` must be the open document that `page_ptr`'s page
// belongs to.
SEXP make_annot_handle(FPDF_ANNOTATION annot, SEXP page_ptr,
                       FPDF_DOCUMENT doc);

// Wrap `page` in an externalptr that pins `doc_ptr` in its prot slot,
// carries the page finalizer, and is registered under the document
// behind `doc_ptr`, which must be open and must own `page`.
SEXP make_page_handle(FPDF_PAGE page, SEXP doc_ptr);

// The same for a font loaded into, and an XObject created in, the
// open document behind `doc_ptr`.
SEXP make_font_handle(FPDF_FONT font, SEXP doc_ptr);
SEXP make_xobject_handle(FPDF_XOBJECT xobject, SEXP doc_ptr);

// Forget the handle, then close what it owns and clear it. Only the
// forgetting happens when the handle is already cleared.
void release_annot_handle(SEXP annot_ptr) noexcept;
void release_page_handle(SEXP page_ptr) noexcept;
void release_font_handle(SEXP font_ptr) noexcept;
void release_xobject_handle(SEXP xobject_ptr) noexcept;

// Release every handle registered under `doc`: annotation contexts
// first, because each refers to its page, then pages, then fonts and
// XObjects. Must run before FPDF_CloseDocument(doc).
void release_doc_handles(FPDF_DOCUMENT doc) noexcept;

// Number of handles registered under `doc`, per kind, in the order
// annotation, page, font, XObject.
std::vector<int> count_doc_handles(FPDF_DOCUMENT doc);

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_HANDLE_REGISTRY_H
