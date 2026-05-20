// pdfium R package — per-attachment handle shims.
//
// PDFium has no documented `FPDFAttachment_Close` function;
// attachment handles are owned by the parent FPDF_DOCUMENT and
// stay valid until the doc closes. The R wrapper accordingly
// stores the handle in an externalptr WITHOUT a finalizer; the
// `prot` slot pins the parent doc so closing the doc explicitly
// (via `pdf_doc_close`) is the only way to release attachment
// memory.
//
// Per-attribute getters live here. Each makes a single PDFium
// call; bulk reads continue to flow through src/attachments.cpp's
// `cpp_attachments_list`.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_attachment.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
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

FPDF_ATTACHMENT att_from_ptr(SEXP att_ptr) {
  if (TYPEOF(att_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the attachment.");
  }
  FPDF_ATTACHMENT a =
      static_cast<FPDF_ATTACHMENT>(R_ExternalPtrAddr(att_ptr));
  if (a == nullptr) {
    Rcpp::stop("Attachment handle is NULL (was the doc closed?).");
  }
  return a;
}

std::string read_utf16_call(
    FPDF_ATTACHMENT a,
    unsigned long (*fn)(FPDF_ATTACHMENT, FPDF_WCHAR*, unsigned long)) {
  unsigned long n_bytes = fn(a, nullptr, 0UL);
  if (n_bytes <= 2) return std::string();
  std::vector<unsigned short> buf(n_bytes / 2);
  fn(a, reinterpret_cast<FPDF_WCHAR*>(buf.data()), n_bytes);
  size_t wchars = (n_bytes >= 2 ? n_bytes / 2 - 1 : n_bytes / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

}  // namespace

// [[Rcpp::export(name = "cpp_attachment_get")]]
SEXP cpp_attachment_get(SEXP doc_ptr, int index_zero_based) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_ATTACHMENT a = FPDFDoc_GetAttachment(doc, index_zero_based);
  if (a == nullptr) {
    Rcpp::stop("FPDFDoc_GetAttachment(%d) returned NULL.",
               index_zero_based);
  }
  // No finalizer: PDFium owns the attachment via the doc. The
  // `prot` slot pins the doc so the attachment outlives no longer
  // than the doc itself.
  return R_MakeExternalPtr(a, R_NilValue, doc_ptr);
}

// [[Rcpp::export(name = "cpp_attachment_name")]]
std::string cpp_attachment_name(SEXP att_ptr) {
  return read_utf16_call(att_from_ptr(att_ptr),
                         FPDFAttachment_GetName);
}

// [[Rcpp::export(name = "cpp_attachment_subtype")]]
std::string cpp_attachment_subtype(SEXP att_ptr) {
  return read_utf16_call(att_from_ptr(att_ptr),
                         FPDFAttachment_GetSubtype);
}

// [[Rcpp::export(name = "cpp_attachment_size_bytes")]]
double cpp_attachment_size_bytes(SEXP att_ptr) {
  FPDF_ATTACHMENT a = att_from_ptr(att_ptr);
  unsigned long out_buflen = 0;
  if (!FPDFAttachment_GetFile(a, nullptr, 0, &out_buflen)) {
    return NA_REAL;
  }
  return static_cast<double>(out_buflen);
}

// [[Rcpp::export(name = "cpp_attachment_data_handle")]]
Rcpp::RawVector cpp_attachment_data_handle(SEXP att_ptr) {
  FPDF_ATTACHMENT a = att_from_ptr(att_ptr);
  unsigned long needed = 0;
  if (!FPDFAttachment_GetFile(a, nullptr, 0, &needed)) {
    Rcpp::stop("FPDFAttachment_GetFile reports unreadable contents.");
  }
  Rcpp::RawVector out(needed);
  if (needed > 0) {
    unsigned long got = 0;
    FPDFAttachment_GetFile(a, &out[0], needed, &got);
  }
  return out;
}

// [[Rcpp::export(name = "cpp_attachment_has_key_handle")]]
bool cpp_attachment_has_key_handle(SEXP att_ptr, std::string key) {
  return FPDFAttachment_HasKey(att_from_ptr(att_ptr), key.c_str());
}

// [[Rcpp::export(name = "cpp_attachment_dict_value_handle")]]
Rcpp::List cpp_attachment_dict_value_handle(SEXP att_ptr,
                                            std::string key) {
  FPDF_ATTACHMENT a = att_from_ptr(att_ptr);
  bool has_key = FPDFAttachment_HasKey(a, key.c_str());
  FPDF_OBJECT_TYPE vtype = 0;
  std::string value_str;
  if (has_key) {
    vtype = FPDFAttachment_GetValueType(a, key.c_str());
    if (vtype == FPDF_OBJECT_STRING || vtype == FPDF_OBJECT_NAME) {
      unsigned long n_bytes =
          FPDFAttachment_GetStringValue(a, key.c_str(), nullptr, 0);
      if (n_bytes > 2) {
        std::vector<unsigned short> buf(n_bytes / 2);
        FPDFAttachment_GetStringValue(
            a, key.c_str(),
            reinterpret_cast<FPDF_WCHAR*>(buf.data()), n_bytes);
        size_t wchars = (n_bytes >= 2 ? n_bytes / 2 - 1
                                       : n_bytes / 2);
        value_str = pdfium_r::utf16le_to_utf8(buf.data(), wchars);
      }
    }
  }
  return Rcpp::List::create(
      Rcpp::_["has_key"]    = has_key,
      Rcpp::_["value_type"] = has_key ? static_cast<int>(vtype)
                                       : NA_INTEGER,
      Rcpp::_["value"]      = value_str.empty()
                                ? Rcpp::CharacterVector(NA_STRING)
                                : Rcpp::CharacterVector::create(value_str));
}
