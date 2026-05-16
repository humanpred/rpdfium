// pdfium R package — AcroForm field readout.
//
// PDF interactive form fields ("AcroForms") are stored as
// FPDF_ANNOT_WIDGET-subtype annotations. PDFium exposes per-field
// metadata through FPDFAnnot_GetFormField* APIs, but those
// require a FPDF_FORMHANDLE - the form-fill environment, which
// must be initialised with FPDFDOC_InitFormFillEnvironment before
// any of the readers will work.
//
// This module wraps the form-fill environment as a per-call
// resource: each call to cpp_form_fields_list opens an
// environment, enumerates every widget annotation across every
// page of the document, reads its field metadata, and closes the
// environment before returning. The R wrapper turns that into a
// single tibble row per form field.
//
// We do not expose FPDF_FORMHANDLE to R. The form-fill
// environment is a session-scoped object whose lifetime would
// require its own S3 class and finalizer; for 0.1.0 we keep it
// internal and pay the small per-call init/teardown cost.

#include <Rcpp.h>
#include <cstdint>
#include <cstring>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_formfill.h"
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

std::string read_form_string(
    FPDF_FORMHANDLE form, FPDF_ANNOTATION annot,
    unsigned long (*getter)(FPDF_FORMHANDLE, FPDF_ANNOTATION,
                            FPDF_WCHAR*, unsigned long)) {
  unsigned long needed = getter(form, annot, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  getter(form, annot,
         reinterpret_cast<FPDF_WCHAR*>(buf.data()), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// Read every choice-list option label for combobox / listbox fields.
std::vector<std::string> read_form_options(
    FPDF_FORMHANDLE form, FPDF_ANNOTATION annot) {
  int n = FPDFAnnot_GetOptionCount(form, annot);
  if (n < 0) return std::vector<std::string>();
  std::vector<std::string> out;
  out.reserve(n);
  for (int i = 0; i < n; ++i) {
    unsigned long needed =
        FPDFAnnot_GetOptionLabel(form, annot, i, nullptr, 0);
    if (needed <= 2) {
      out.emplace_back();
      continue;
    }
    std::vector<unsigned short> buf(needed / 2);
    FPDFAnnot_GetOptionLabel(form, annot, i,
                             reinterpret_cast<FPDF_WCHAR*>(buf.data()),
                             needed);
    size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
    out.emplace_back(pdfium_r::utf16le_to_utf8(buf.data(), wchars));
  }
  return out;
}

}  // namespace

// [[Rcpp::export(name = "cpp_form_fields_list")]]
Rcpp::List cpp_form_fields_list(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);

  // Init a minimal form-fill environment. The struct's version
  // field must be set; the function pointers may be NULL for the
  // read-only path we exercise.
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) {
    // Document has no AcroForm dictionary - no fields to enumerate.
    return Rcpp::List::create(
        Rcpp::_["page_num"]      = Rcpp::IntegerVector(),
        Rcpp::_["field_type"]    = Rcpp::IntegerVector(),
        Rcpp::_["field_flags"]   = Rcpp::IntegerVector(),
        Rcpp::_["name"]          = Rcpp::CharacterVector(),
        Rcpp::_["alternate_name"] = Rcpp::CharacterVector(),
        Rcpp::_["value"]         = Rcpp::CharacterVector(),
        Rcpp::_["bounds_left"]    = Rcpp::NumericVector(),
        Rcpp::_["bounds_bottom"]  = Rcpp::NumericVector(),
        Rcpp::_["bounds_right"]   = Rcpp::NumericVector(),
        Rcpp::_["bounds_top"]     = Rcpp::NumericVector(),
        Rcpp::_["options"]       = Rcpp::List());
  }

  std::vector<int> page_nums;
  std::vector<int> field_types;
  std::vector<int> field_flags;
  std::vector<std::string> names;
  std::vector<std::string> alt_names;
  std::vector<std::string> values;
  std::vector<double> lefts;
  std::vector<double> bottoms;
  std::vector<double> rights;
  std::vector<double> tops;
  Rcpp::List options;

  int page_count = FPDF_GetPageCount(doc);
  for (int p = 0; p < page_count; ++p) {
    FPDF_PAGE page = FPDF_LoadPage(doc, p);
    if (page == nullptr) continue;
    int n_annots = FPDFPage_GetAnnotCount(page);
    for (int ai = 0; ai < n_annots; ++ai) {
      FPDF_ANNOTATION annot = FPDFPage_GetAnnot(page, ai);
      if (annot == nullptr) continue;
      if (FPDFAnnot_GetSubtype(annot) != FPDF_ANNOT_WIDGET) {
        FPDFPage_CloseAnnot(annot);
        continue;
      }
      int ftype = FPDFAnnot_GetFormFieldType(form, annot);
      page_nums.push_back(p + 1);
      field_types.push_back(ftype < 0 ? NA_INTEGER : ftype);
      field_flags.push_back(
          FPDFAnnot_GetFormFieldFlags(form, annot));
      names.push_back(
          read_form_string(form, annot, FPDFAnnot_GetFormFieldName));
      alt_names.push_back(read_form_string(
          form, annot, FPDFAnnot_GetFormFieldAlternateName));
      values.push_back(
          read_form_string(form, annot, FPDFAnnot_GetFormFieldValue));
      FS_RECTF rect;
      if (FPDFAnnot_GetRect(annot, &rect)) {
        lefts.push_back(rect.left);
        bottoms.push_back(rect.bottom);
        rights.push_back(rect.right);
        tops.push_back(rect.top);
      } else {
        lefts.push_back(NA_REAL);
        bottoms.push_back(NA_REAL);
        rights.push_back(NA_REAL);
        tops.push_back(NA_REAL);
      }
      options.push_back(Rcpp::wrap(read_form_options(form, annot)));
      FPDFPage_CloseAnnot(annot);
    }
    FPDF_ClosePage(page);
  }
  FPDFDOC_ExitFormFillEnvironment(form);

  return Rcpp::List::create(
      Rcpp::_["page_num"]       = page_nums,
      Rcpp::_["field_type"]     = field_types,
      Rcpp::_["field_flags"]    = field_flags,
      Rcpp::_["name"]           = names,
      Rcpp::_["alternate_name"] = alt_names,
      Rcpp::_["value"]          = values,
      Rcpp::_["bounds_left"]    = lefts,
      Rcpp::_["bounds_bottom"]  = bottoms,
      Rcpp::_["bounds_right"]   = rights,
      Rcpp::_["bounds_top"]     = tops,
      Rcpp::_["options"]        = options);
}
