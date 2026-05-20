// pdfium R package — shared C-side defensive validation (ADR-020 §4).
//
// Every cpp_* Rcpp shim that accepts a PDFium-handle externalptr
// must validate three things at entry:
//
//   1. The argument is an EXTPTRSXP (defends against R-side
//      bypass that passes the wrong R type).
//   2. The externalptr's `prot` slot — when it's itself an
//      externalptr (which is the convention for child handles
//      that pin their parent) — has a non-NULL address. When the
//      parent doc / page has been closed, the parent externalptr
//      is cleared and the child's pointer dangles into freed
//      memory; this is the check that prevents dereferencing
//      free()'d FPDF_* memory.
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

// Validate the externalptr `ptr` and return its underlying address.
// `what` names the handle class (used in error messages).
// When `require_prot_alive` is true the prot slot must be an
// externalptr whose own address is non-NULL — this catches the
// "parent was closed, child still references freed memory" case.
inline void* validate_handle(SEXP ptr, const char* what,
                              bool require_prot_alive) {
  if (TYPEOF(ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the %s.", what);
  }
  if (require_prot_alive) {
    SEXP prot = R_ExternalPtrProtected(ptr);
    // prot is only treated as a liveness signal when it's itself
    // an externalptr. Some handles (e.g. pdfium_doc itself) carry
    // R_NilValue or a non-extptr in prot; for those we skip the
    // parent-liveness check and rely on the own-address check
    // below.
    if (TYPEOF(prot) == EXTPTRSXP &&
        R_ExternalPtrAddr(prot) == nullptr) {
      Rcpp::stop(
          "%s handle's parent has been closed (the underlying "
          "pointer is no longer valid).", what);
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
