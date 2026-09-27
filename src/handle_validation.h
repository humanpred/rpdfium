// pdfium R package — shared C-side defensive validation (ADR-020 §4,
// ADR-029).
//
// Every cpp_* Rcpp shim that accepts a PDFium-handle externalptr
// must validate three things at entry:
//
//   1. The argument is an EXTPTRSXP (defends against R-side
//      bypass that passes the wrong R type).
//   2. Every owner on the handle's `prot` chain has a non-NULL
//      address. A child handle pins its immediate owner in `prot`
//      (a clip path its page-object, a page-object its form, a form
//      its annotation or page, a page its document), and each owner
//      pins its own. Closing, deleting or moving an owner clears
//      its externalptr, and every handle below it then points into
//      memory PDFium has freed or no longer lets it reach; this is
//      the check that prevents dereferencing it.
//   3. The externalptr's own address is non-NULL.
//
// All three errors raise Rcpp::stop with a readable message. No
// crashes ever, even with post-close input passed in through
// `pdfium:::cpp_*` direct calls.
//
// The "what" string is included in the message so the user knows
// which handle class tripped the guard (e.g. "attachment",
// "signature", "bookmark"). Adapters in each *_handles.cpp file
// thin-wrap these helpers and cast the returned void* to the
// concrete FPDF_* type.

#ifndef PDFIUM_R_PKG_HANDLE_VALIDATION_H
#define PDFIUM_R_PKG_HANDLE_VALIDATION_H

#include <Rcpp.h>

namespace pdfium_r {

// Longest `prot` chain validate_handle() walks. The longest real chain
// runs from a clip path through its page-object, one form object per
// level of Form XObject nesting (PDFium parses 40 levels), an
// annotation, the page and the document to its memory buffer. A
// handle's `prot` is fixed when the handle is made, so a chain cannot
// loop back on itself; the cap only bounds the walk.
constexpr int kMaxOwnerChain = 64;

// Validate the externalptr `ptr` and return its underlying address.
// `what` names the handle class (used in error messages).
// When `require_prot_alive` is true, every externalptr on the prot
// chain must have a non-NULL address — this catches the "an owner was
// closed, the child still references freed memory" case. The walk
// stops at the first prot that is not an externalptr: the document
// handle carries R_NilValue, or its memory buffer, whose own prot is
// R_NilValue.
inline void* validate_handle(SEXP ptr, const char* what,
                              bool require_prot_alive) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the %s.", what);
  }
  if (require_prot_alive) {
    SEXP owner = R_ExternalPtrProtected(ptr);
    for (int depth = 0; TYPEOF(owner) == EXTPTRSXP; ++depth) {
      if (depth == kMaxOwnerChain) {
        // # nocov start — no handle the package makes has a chain
        // this long (see kMaxOwnerChain).
        Rcpp::stop("%s handle's chain of owners is longer than %d.",
                   what, kMaxOwnerChain);
        // # nocov end
      }
      if (R_ExternalPtrAddr(owner) == nullptr) {
        Rcpp::stop(
            "%s handle's parent has been closed (the underlying "
            "pointer is no longer valid).", what);
      }
      owner = R_ExternalPtrProtected(owner);
    }
  }
  void* addr = R_ExternalPtrAddr(ptr);
  if (addr == nullptr) {
    Rcpp::stop("%s handle is NULL (closed?).", what);
  }
  return addr;
}

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_HANDLE_VALIDATION_H
