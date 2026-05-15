// pdfium R package — document-level metadata accessors.
//
// Wraps the FPDF_GetMetaText / FPDF_GetFileVersion family for the
// pdf_doc_info() / pdf_doc_meta() / pdf_doc_file_version() R-side
// API. FPDF_GetMetaText follows the same byte-counted UTF-16LE
// protocol as FPDFTextObj_GetText: a NULL/0 sizing call returns the
// number of bytes (including the trailing NUL) and the real call
// fills the supplied buffer.

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"
#include "utf16.h"

using pdfium_r::utf16le_to_utf8;

namespace {

// Read one document metadata tag via FPDF_GetMetaText. Returns the
// decoded UTF-8 string, or an empty string when the tag is absent
// or empty.
std::string read_meta_text(FPDF_DOCUMENT doc, const char* tag) {
  unsigned long n_bytes = FPDF_GetMetaText(doc, tag, nullptr, 0UL);
  if (n_bytes < 2) return std::string();
  size_t n_wchars = n_bytes / 2;
  std::vector<unsigned short> buf(n_wchars);
  FPDF_GetMetaText(doc, tag, buf.data(), n_bytes);
  return utf16le_to_utf8(buf.data(), n_wchars - 1);
}

// Build a CHARSXP from a std::string with the UTF-8 encoding flag.
inline SEXP utf8_charsxp(const std::string& s) {
  return Rf_mkCharLenCE(s.data(), static_cast<int>(s.size()), CE_UTF8);
}

}  // namespace

// [[Rcpp::export(name = "cpp_doc_meta_text")]]
SEXP cpp_doc_meta_text(SEXP doc_ptr, std::string tag) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) Rcpp::stop("Expected an external pointer.");
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  std::string s = read_meta_text(doc, tag.c_str());
  SEXP r_chr = PROTECT(utf8_charsxp(s));
  SEXP r_vec = PROTECT(Rf_allocVector(STRSXP, 1));
  SET_STRING_ELT(r_vec, 0, r_chr);
  UNPROTECT(2);
  return r_vec;
}

// [[Rcpp::export(name = "cpp_doc_info")]]
Rcpp::List cpp_doc_info(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) Rcpp::stop("Expected an external pointer.");
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");

  // PDF spec standard Info-dictionary tags. PDFium accepts these
  // strings verbatim against FPDF_GetMetaText.
  const char* tags[] = {
    "Title", "Author", "Subject", "Keywords",
    "Creator", "Producer", "CreationDate", "ModDate", "Trapped"
  };
  const char* names[] = {
    "title", "author", "subject", "keywords",
    "creator", "producer", "creation_date", "mod_date", "trapped"
  };
  const size_t n_tags = sizeof(tags) / sizeof(tags[0]);

  Rcpp::CharacterVector vals(n_tags);
  Rcpp::CharacterVector nms(n_tags);
  for (size_t i = 0; i < n_tags; ++i) {
    std::string s = read_meta_text(doc, tags[i]);
    vals[i] = utf8_charsxp(s);
    nms[i]  = names[i];
  }
  vals.attr("names") = nms;
  return Rcpp::List::create(
    Rcpp::_["page_count"]  = FPDF_GetPageCount(doc),
    Rcpp::_["meta"]        = vals
  );
}

// [[Rcpp::export(name = "cpp_doc_file_version")]]
int cpp_doc_file_version(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) Rcpp::stop("Expected an external pointer.");
  FPDF_DOCUMENT doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  int v = 0;
  if (!FPDF_GetFileVersion(doc, &v)) return NA_INTEGER;
  // PDFium reports as 10 * major + minor (e.g. 17 means PDF 1.7).
  return v;
}
