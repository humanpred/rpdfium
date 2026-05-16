// pdfium R package — digital-signature readout.
//
// PDF can carry one or more digital signatures (PDF spec 12.8).
// PDFium exposes them as FPDF_SIGNATURE handles owned by the
// parent document. Per-signature scalar fields plus two
// variable-length blobs (the cryptographic contents and the
// signed byte ranges):
//
//   FPDF_GetSignatureCount(doc)
//   FPDF_GetSignatureObject(doc, index)
//   FPDFSignatureObj_GetSubFilter      (ASCII)
//   FPDFSignatureObj_GetReason         (UTF-16LE)
//   FPDFSignatureObj_GetTime           (ASCII, "D:YYYYMMDDHHMMSS+XX'YY'")
//   FPDFSignatureObj_GetDocMDPPermission (1/2/3, 0 on error)
//   FPDFSignatureObj_GetContents       (PKCS#1 or PKCS#7 DER)
//   FPDFSignatureObj_GetByteRange      (int[2*n]: offset, length pairs)
//
// The R wrapper exposes the scalars as a tibble row and the two
// blobs through separate accessors.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_signature.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

std::string read_ascii_field(
    FPDF_SIGNATURE sig,
    unsigned long (*getter)(FPDF_SIGNATURE, char*, unsigned long)) {
  unsigned long needed = getter(sig, nullptr, 0);
  if (needed == 0) return std::string();
  std::vector<char> buf(needed);
  getter(sig, buf.data(), needed);
  // PDFium reports length including the trailing NUL.
  size_t len = (needed >= 1 ? needed - 1 : needed);
  return std::string(buf.data(), len);
}

std::string read_utf16_reason(FPDF_SIGNATURE sig) {
  unsigned long needed =
      FPDFSignatureObj_GetReason(sig, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDFSignatureObj_GetReason(sig, buf.data(), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

}  // namespace

// [[Rcpp::export(name = "cpp_signature_count")]]
int cpp_signature_count(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  int n = FPDF_GetSignatureCount(doc);
  if (n < 0) {
    Rcpp::stop("FPDF_GetSignatureCount returned %d.", n);
  }
  return n;
}

// [[Rcpp::export(name = "cpp_signatures_list")]]
Rcpp::List cpp_signatures_list(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  int n = FPDF_GetSignatureCount(doc);
  if (n < 0) n = 0;

  Rcpp::CharacterVector sub_filter(n);
  Rcpp::CharacterVector reason(n);
  Rcpp::CharacterVector time_str(n);
  Rcpp::IntegerVector   doc_mdp(n);
  Rcpp::IntegerVector   contents_size(n);
  Rcpp::IntegerVector   byte_range_pairs(n);

  for (int i = 0; i < n; ++i) {
    FPDF_SIGNATURE sig = FPDF_GetSignatureObject(doc, i);
    if (sig == nullptr) {
      sub_filter[i] = NA_STRING;
      reason[i]     = NA_STRING;
      time_str[i]   = NA_STRING;
      doc_mdp[i]    = NA_INTEGER;
      contents_size[i] = NA_INTEGER;
      byte_range_pairs[i] = NA_INTEGER;
      continue;
    }
    sub_filter[i] = read_ascii_field(sig, FPDFSignatureObj_GetSubFilter);
    reason[i]     = read_utf16_reason(sig);
    time_str[i]   = read_ascii_field(sig, FPDFSignatureObj_GetTime);
    unsigned int mdp = FPDFSignatureObj_GetDocMDPPermission(sig);
    doc_mdp[i] = (mdp == 0u) ? NA_INTEGER : static_cast<int>(mdp);
    contents_size[i] = static_cast<int>(
        FPDFSignatureObj_GetContents(sig, nullptr, 0));
    // GetByteRange returns the count in ints (2 per pair).
    unsigned long br_ints = FPDFSignatureObj_GetByteRange(sig, nullptr, 0);
    byte_range_pairs[i] = static_cast<int>(br_ints / 2u);
  }
  return Rcpp::List::create(
      Rcpp::_["sub_filter"]       = sub_filter,
      Rcpp::_["reason"]           = reason,
      Rcpp::_["time"]             = time_str,
      Rcpp::_["doc_mdp_permission"] = doc_mdp,
      Rcpp::_["contents_size"]    = contents_size,
      Rcpp::_["byte_range_pairs"] = byte_range_pairs);
}

// [[Rcpp::export(name = "cpp_signature_contents")]]
Rcpp::RawVector cpp_signature_contents(SEXP doc_ptr, int index_zero) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_SIGNATURE sig = FPDF_GetSignatureObject(doc, index_zero);
  if (sig == nullptr) {
    Rcpp::stop("FPDF_GetSignatureObject returned NULL for index %d.",
               index_zero);
  }
  unsigned long needed = FPDFSignatureObj_GetContents(sig, nullptr, 0);
  Rcpp::RawVector out(static_cast<R_xlen_t>(needed));
  if (needed > 0) {
    FPDFSignatureObj_GetContents(sig, &out[0], needed);
  }
  return out;
}

// [[Rcpp::export(name = "cpp_signature_byte_range")]]
Rcpp::IntegerMatrix cpp_signature_byte_range(SEXP doc_ptr,
                                             int index_zero) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_SIGNATURE sig = FPDF_GetSignatureObject(doc, index_zero);
  if (sig == nullptr) {
    Rcpp::stop("FPDF_GetSignatureObject returned NULL for index %d.",
               index_zero);
  }
  unsigned long n_ints = FPDFSignatureObj_GetByteRange(sig, nullptr, 0);
  // n_ints is 2 * pair_count (offset + length per pair).
  int pairs = static_cast<int>(n_ints / 2u);
  Rcpp::IntegerMatrix out(pairs, 2);
  if (n_ints > 0) {
    std::vector<int> buf(n_ints);
    FPDFSignatureObj_GetByteRange(sig, buf.data(), n_ints);
    for (int p = 0; p < pairs; ++p) {
      out(p, 0) = buf[p * 2];      // offset
      out(p, 1) = buf[p * 2 + 1];  // length
    }
  }
  Rcpp::CharacterVector cn(2);
  cn[0] = "offset";
  cn[1] = "length";
  Rcpp::colnames(out) = cn;
  return out;
}
