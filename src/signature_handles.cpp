// pdfium R package — per-signature handle shims.
//
// PDFium has no documented FPDFSignature_Close call; signatures
// are owned by their parent FPDF_DOCUMENT. The R wrapper accordingly
// stores each handle in an externalptr WITHOUT a finalizer; the
// `prot` slot pins the parent doc.

#include <Rcpp.h>
#include <cstring>
#include <vector>
#include "fpdfview.h"
#include "fpdf_signature.h"
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

FPDF_SIGNATURE sig_from_ptr(SEXP sig_ptr) {
  if (TYPEOF(sig_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the signature.");
  }
  FPDF_SIGNATURE s =
      static_cast<FPDF_SIGNATURE>(R_ExternalPtrAddr(sig_ptr));
  if (s == nullptr) {
    Rcpp::stop("Signature handle is NULL (was the doc closed?).");
  }
  return s;
}

std::string read_sig_reason(FPDF_SIGNATURE s) {
  unsigned long needed = FPDFSignatureObj_GetReason(s, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDFSignatureObj_GetReason(s, buf.data(), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

std::string read_ascii(
    FPDF_SIGNATURE s,
    unsigned long (*fn)(FPDF_SIGNATURE, char*, unsigned long)) {
  unsigned long needed = fn(s, nullptr, 0);
  if (needed == 0) return std::string();
  std::vector<char> buf(needed);
  fn(s, buf.data(), needed);
  // The reported length includes a trailing NUL — drop it.
  if (!buf.empty() && buf.back() == '\0') buf.pop_back();
  return std::string(buf.begin(), buf.end());
}

}  // namespace

// [[Rcpp::export(name = "cpp_signature_get")]]
SEXP cpp_signature_get(SEXP doc_ptr, int index_zero_based) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_SIGNATURE s = FPDF_GetSignatureObject(doc, index_zero_based);
  if (s == nullptr) {
    Rcpp::stop("FPDF_GetSignatureObject(%d) returned NULL.",
               index_zero_based);
  }
  // No finalizer; doc owns it. PDFium types FPDF_SIGNATURE as a
  // `const` pointer; R_MakeExternalPtr takes `void*`, so we
  // const_cast away the qualifier — the R-side wrapper never
  // mutates through the pointer.
  return R_MakeExternalPtr(const_cast<void*>(static_cast<const void*>(s)),
                            R_NilValue, doc_ptr);
}

// [[Rcpp::export(name = "cpp_signature_sub_filter_handle")]]
std::string cpp_signature_sub_filter_handle(SEXP sig_ptr) {
  return read_ascii(sig_from_ptr(sig_ptr),
                    FPDFSignatureObj_GetSubFilter);
}

// [[Rcpp::export(name = "cpp_signature_reason_handle")]]
std::string cpp_signature_reason_handle(SEXP sig_ptr) {
  return read_sig_reason(sig_from_ptr(sig_ptr));
}

// [[Rcpp::export(name = "cpp_signature_time_handle")]]
std::string cpp_signature_time_handle(SEXP sig_ptr) {
  return read_ascii(sig_from_ptr(sig_ptr), FPDFSignatureObj_GetTime);
}

// [[Rcpp::export(name = "cpp_signature_docmdp_handle")]]
int cpp_signature_docmdp_handle(SEXP sig_ptr) {
  int v = FPDFSignatureObj_GetDocMDPPermission(sig_from_ptr(sig_ptr));
  // PDFium returns 0 when the signature has no DocMDP entry; map
  // to NA so the R side surfaces "no entry" cleanly.
  return v == 0 ? NA_INTEGER : v;
}

// [[Rcpp::export(name = "cpp_signature_contents_handle")]]
Rcpp::RawVector cpp_signature_contents_handle(SEXP sig_ptr) {
  FPDF_SIGNATURE s = sig_from_ptr(sig_ptr);
  unsigned long needed = FPDFSignatureObj_GetContents(s, nullptr, 0);
  Rcpp::RawVector out(needed);
  if (needed > 0) {
    FPDFSignatureObj_GetContents(s, &out[0], needed);
  }
  return out;
}

// [[Rcpp::export(name = "cpp_signature_byte_range_handle")]]
Rcpp::IntegerMatrix cpp_signature_byte_range_handle(SEXP sig_ptr) {
  FPDF_SIGNATURE s = sig_from_ptr(sig_ptr);
  // Byte range: array of int pairs (offset, length). First call with
  // null buffer returns the element count; pairs = count / 2.
  int count = FPDFSignatureObj_GetByteRange(s, nullptr, 0);
  if (count <= 0) return Rcpp::IntegerMatrix(0, 2);
  std::vector<int> buf(count);
  FPDFSignatureObj_GetByteRange(s, buf.data(), count);
  int pairs = count / 2;
  Rcpp::IntegerMatrix out(pairs, 2);
  for (int i = 0; i < pairs; ++i) {
    out(i, 0) = buf[2 * i];
    out(i, 1) = buf[2 * i + 1];
  }
  Rcpp::CharacterVector cn = Rcpp::CharacterVector::create(
      "offset", "length");
  Rcpp::colnames(out) = cn;
  return out;
}
