// pdfium R package — closing FPDF_DOCUMENT handles (ADR-024).
//
// Every FPDF_CloseDocument call in the package goes through
// close_document_handle(), which first releases the document's live
// annotation handles (annot_registry.h). Code that mints a document
// externalptr registers finalize_document as its finalizer.

#ifndef PDFIUM_R_PKG_DOCUMENT_HANDLE_H
#define PDFIUM_R_PKG_DOCUMENT_HANDLE_H

#include <Rcpp.h>

namespace pdfium_r {

// Close the document behind the externalptr `doc_ptr` and clear it.
// A no-op when `doc_ptr` is already cleared.
void close_document_handle(SEXP doc_ptr);

// C finalizer for document externalptrs.
void finalize_document(SEXP doc_ptr);

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_DOCUMENT_HANDLE_H
