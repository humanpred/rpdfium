// pdfium R package — lifetime of every handle with a finalizer
// (ADR-024, ADR-025, ADR-028).
//
// PDFium expects every page, annotation context, font and XObject to
// be closed before the document it belongs to, and every document,
// clip path and bitmap before FPDF_DestroyLibrary(). The package keeps
// that order in every teardown: each live handle is registered under
// what it must be closed before. Annotation contexts, pages, fonts and
// XObjects are registered under their FPDF_DOCUMENT; documents, the
// clip paths of pdf_clip_path_new(), bitmaps and the buffers that
// documents loaded from memory read from are registered under the
// library. Closing a document releases the handles registered under it
// first, and destroying the library releases every handle registered
// under it, each document with its own handles, first.
//
// For each kind, make_*_handle() is the only way to create the
// externalptr, and the only code that attaches a finalizer, and
// release_*_handle() is the only way to clear it: the finalizer, the
// explicit close (pdf_doc_close(), pdf_page_close(), pdf_font_close(),
// pdf_xobject_close(), pdf_clip_path_close(), pdf_bitmap_close(),
// pdf_annot_delete()) and the release of the owner all go through it,
// so the registry never holds a handle R has freed.

#ifndef PDFIUM_R_PKG_HANDLE_REGISTRY_H
#define PDFIUM_R_PKG_HANDLE_REGISTRY_H

#include <Rcpp.h>
#include <vector>
#include "fpdfview.h"

namespace pdfium_r {

// Initialise PDFium unless it is initialised already. Every entry point
// that creates a handle without an open document calls it first, so
// the library comes back after cpp_destroy_library().
void ensure_library_initialised();

// Wrap `doc` in an externalptr that holds `prot` (R_NilValue, or the
// externalptr of the buffer a document loaded from memory reads from)
// in its prot slot, carries the document finalizer, and is registered
// under the library.
SEXP make_document_handle(FPDF_DOCUMENT doc, SEXP prot);

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

// Wrap a clip path from FPDF_CreateClipPath(), or a bitmap from
// FPDFBitmap_Create(), in an externalptr with its finalizer, registered
// under the library. Neither belongs to a document.
SEXP make_clip_path_handle(FPDF_CLIPPATH clip_path);
SEXP make_bitmap_handle(FPDF_BITMAP bitmap);

// Wrap `buffer`, allocated with new[] for a document to read from, in
// an externalptr whose finalizer frees it, registered under the
// library. The document's handle pins it in its prot slot, because
// PDFium reads the buffer until the document is closed.
SEXP make_buffer_handle(unsigned char* buffer);

// Forget the handle, then close what it owns and clear it. Only the
// forgetting happens when the handle is already cleared. Releasing a
// document first releases the handles registered under it.
void release_document_handle(SEXP doc_ptr) noexcept;
void release_annot_handle(SEXP annot_ptr) noexcept;
void release_page_handle(SEXP page_ptr) noexcept;
void release_font_handle(SEXP font_ptr) noexcept;
void release_xobject_handle(SEXP xobject_ptr) noexcept;
void release_clip_path_handle(SEXP clip_path_ptr) noexcept;
void release_bitmap_handle(SEXP bitmap_ptr) noexcept;
void release_buffer_handle(SEXP buffer_ptr) noexcept;

// Release every handle registered under the library: documents, each
// after the handles registered under it, then clip paths, bitmaps and
// buffers. Must run before FPDF_DestroyLibrary().
void release_library_handles() noexcept;

// Number of handles registered under the document `doc`, per kind, in
// the order annotation, page, font, XObject; and under the library, in
// the order document, clip path, bitmap, buffer.
std::vector<int> count_doc_handles(FPDF_DOCUMENT doc);
std::vector<int> count_library_handles();

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_HANDLE_REGISTRY_H
