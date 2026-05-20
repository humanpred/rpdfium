// pdfium R package — attachment authoring (Phase 8).
//
// Four shims, each thin around its FPDFDoc_*Attachment* /
// FPDFAttachment_Set* counterpart:
//
//   cpp_attachment_new          - FPDFDoc_AddAttachment
//   cpp_attachment_delete       - FPDFDoc_DeleteAttachment
//   cpp_attachment_set_dict_value - FPDFAttachment_SetStringValue
//   cpp_attachment_set_data     - FPDFAttachment_SetFile
//
// The handle returned by cpp_attachment_new wraps the new
// FPDF_ATTACHMENT in an externalptr that pins the parent doc (same
// convention as cpp_attachment_get). No finalizer is registered —
// PDFium owns attachments via the doc.
//
// PDFium's FPDFDoc_DeleteAttachment takes a doc + index, not the
// attachment handle, so the R-side wrapper passes both: the
// attachment's externalptr lets us null it after the delete so the
// stale handle can't be used to dereference freed memory.

#include <Rcpp.h>
#include <cstdint>
#include "fpdfview.h"
#include "fpdf_attachment.h"
#include "handle_validation.h"
#include "utf16.h"

namespace {

inline FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

inline FPDF_ATTACHMENT att_from_ptr(SEXP att_ptr) {
  return static_cast<FPDF_ATTACHMENT>(
      pdfium_r::validate_handle(att_ptr, "Attachment",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// [[Rcpp::export(name = "cpp_attachment_new")]]
SEXP cpp_attachment_new(SEXP doc_ptr, std::string name_utf8) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  std::vector<unsigned short> nm = pdfium_r::utf8_to_utf16le_nul(name_utf8);
  FPDF_ATTACHMENT a = FPDFDoc_AddAttachment(
      doc, reinterpret_cast<FPDF_WIDESTRING>(nm.data()));
  if (a == nullptr) {
    Rcpp::stop("FPDFDoc_AddAttachment returned NULL (duplicate "
               "name, empty name, or name-tree depth limit?).");
  }
  // No finalizer; doc owns it. Prot pins the parent doc.
  return R_MakeExternalPtr(a, R_NilValue, doc_ptr);
}

// [[Rcpp::export(name = "cpp_attachment_delete")]]
bool cpp_attachment_delete(SEXP doc_ptr, int index_zero_based) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  return FPDFDoc_DeleteAttachment(doc, index_zero_based) != 0;
}

// [[Rcpp::export(name = "cpp_attachment_clear_ptr")]]
void cpp_attachment_clear_ptr(SEXP att_ptr) {
  // The C-side validation passes require_prot_alive = true on every
  // attachment shim; after the parent doc deletes the attachment by
  // index, this externalptr is stale (its underlying FPDF_ATTACHMENT
  // is freed). Clearing the address makes subsequent shim calls
  // raise the "Attachment handle is NULL" guard, matching the
  // pdf_obj_delete / pdf_annot_delete idempotency contract.
  if (TYPEOF(att_ptr) == EXTPTRSXP) {
    R_ClearExternalPtr(att_ptr);
  }
}

// [[Rcpp::export(name = "cpp_attachment_set_dict_value")]]
bool cpp_attachment_set_dict_value(SEXP att_ptr,
                                    std::string key,
                                    std::string value_utf8) {
  FPDF_ATTACHMENT a = att_from_ptr(att_ptr);
  std::vector<unsigned short> v =
      pdfium_r::utf8_to_utf16le_nul(value_utf8);
  return FPDFAttachment_SetStringValue(
      a, key.c_str(),
      reinterpret_cast<FPDF_WIDESTRING>(v.data())) != 0;
}

// [[Rcpp::export(name = "cpp_attachment_set_data")]]
bool cpp_attachment_set_data(SEXP att_ptr,
                              SEXP doc_ptr,
                              Rcpp::RawVector contents) {
  FPDF_ATTACHMENT a = att_from_ptr(att_ptr);
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  const void* data = contents.size() > 0 ? &contents[0] : nullptr;
  return FPDFAttachment_SetFile(
      a, doc, data,
      static_cast<unsigned long>(contents.size())) != 0;
}
