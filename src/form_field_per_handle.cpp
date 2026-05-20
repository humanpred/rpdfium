// pdfium R package — per-form-field handle shims.
//
// Companion to src/form_field_handles.cpp (which builds the handle
// list). Each shim takes (annot_ptr, doc_ptr) where annot_ptr is
// the widget annotation externalptr that backs a `pdfium_form_field`
// handle, and doc_ptr is the parent doc's externalptr. PDFium's
// AcroForm accessors need both — the annotation identifies the
// field, the doc seeds the FPDF_FORMHANDLE that classifies it.
//
// Lifetime: the doc owns the form-fill environment indirectly via
// FPDFDOC_InitFormFillEnvironment / FPDFDOC_ExitFormFillEnvironment.
// We open and close it inside each call (matching the bulk reader);
// ADR-013 leaves the door open to a future cached handle.

#include <Rcpp.h>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_formfill.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT ff_doc_from_ptr(SEXP doc_ptr) {
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

FPDF_ANNOTATION ff_annot_from_ptr(SEXP annot_ptr) {
  if (TYPEOF(annot_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the annotation.");
  }
  FPDF_ANNOTATION a =
      static_cast<FPDF_ANNOTATION>(R_ExternalPtrAddr(annot_ptr));
  if (a == nullptr) {
    Rcpp::stop("Annotation handle is NULL (closed?).");
  }
  return a;
}

// RAII wrapper around FPDFDOC_InitFormFillEnvironment. Init may
// return nullptr when the doc has no AcroForm dict — getters above
// treat that as "no field" and return empty/NA.
struct FFIGuard {
  FPDF_FORMFILLINFO ffi{};
  FPDF_FORMHANDLE form = nullptr;
  explicit FFIGuard(FPDF_DOCUMENT doc) {
    ffi.version = 2;
    form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  }
  ~FFIGuard() {
    if (form != nullptr) FPDFDOC_ExitFormFillEnvironment(form);
  }
  FFIGuard(const FFIGuard&) = delete;
  FFIGuard& operator=(const FFIGuard&) = delete;
};

// Two-pass UTF-16 read for an FPDFAnnot_GetForm*-family string.
std::string read_ff_string(
    FPDF_FORMHANDLE form, FPDF_ANNOTATION a,
    unsigned long (*fn)(FPDF_FORMHANDLE, FPDF_ANNOTATION, FPDF_WCHAR*,
                         unsigned long)) {
  unsigned long needed = fn(form, a, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  fn(form, a, reinterpret_cast<FPDF_WCHAR*>(buf.data()), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

}  // namespace

// [[Rcpp::export(name = "cpp_form_field_name_handle")]]
std::string cpp_form_field_name_handle(SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return std::string();
  return read_ff_string(ffi.form, a, FPDFAnnot_GetFormFieldName);
}

// [[Rcpp::export(name = "cpp_form_field_alternate_name_handle")]]
std::string cpp_form_field_alternate_name_handle(SEXP annot_ptr,
                                                   SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return std::string();
  return read_ff_string(ffi.form, a,
                         FPDFAnnot_GetFormFieldAlternateName);
}

// [[Rcpp::export(name = "cpp_form_field_value_handle")]]
std::string cpp_form_field_value_handle(SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return std::string();
  return read_ff_string(ffi.form, a, FPDFAnnot_GetFormFieldValue);
}

// [[Rcpp::export(name = "cpp_form_field_export_value_handle")]]
std::string cpp_form_field_export_value_handle(SEXP annot_ptr,
                                                 SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return std::string();
  return read_ff_string(ffi.form, a, FPDFAnnot_GetFormFieldExportValue);
}

// [[Rcpp::export(name = "cpp_form_field_flags_handle")]]
int cpp_form_field_flags_handle(SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return NA_INTEGER;
  return FPDFAnnot_GetFormFieldFlags(ffi.form, a);
}

// [[Rcpp::export(name = "cpp_form_field_is_checked_handle")]]
int cpp_form_field_is_checked_handle(SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return NA_INTEGER;
  // FPDFAnnot_IsChecked returns 1 / 0; for non-checkbox / non-radio
  // widgets FPDFium returns 0, indistinguishable from "unchecked".
  // The R wrapper layers on the type-based gating already in place
  // for the tibble view.
  return FPDFAnnot_IsChecked(ffi.form, a) ? 1 : 0;
}

// [[Rcpp::export(name = "cpp_form_field_control_count_handle")]]
int cpp_form_field_control_count_handle(SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return NA_INTEGER;
  int v = FPDFAnnot_GetFormControlCount(ffi.form, a);
  return v < 0 ? NA_INTEGER : v;
}

// [[Rcpp::export(name = "cpp_form_field_control_index_handle")]]
int cpp_form_field_control_index_handle(SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return NA_INTEGER;
  int v = FPDFAnnot_GetFormControlIndex(ffi.form, a);
  return v < 0 ? NA_INTEGER : v;
}

// [[Rcpp::export(name = "cpp_form_field_options_handle")]]
Rcpp::CharacterVector cpp_form_field_options_handle(SEXP annot_ptr,
                                                     SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return Rcpp::CharacterVector();
  int n = FPDFAnnot_GetOptionCount(ffi.form, a);
  if (n <= 0) return Rcpp::CharacterVector();
  Rcpp::CharacterVector out(n);
  for (int i = 0; i < n; ++i) {
    unsigned long needed =
        FPDFAnnot_GetOptionLabel(ffi.form, a, i, nullptr, 0);
    if (needed <= 2) { out[i] = ""; continue; }
    std::vector<unsigned short> buf(needed / 2);
    FPDFAnnot_GetOptionLabel(ffi.form, a, i,
                              reinterpret_cast<FPDF_WCHAR*>(buf.data()),
                              needed);
    size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
    out[i] = pdfium_r::utf16le_to_utf8(buf.data(), wchars);
  }
  return out;
}

// [[Rcpp::export(name = "cpp_form_field_is_option_selected_handle")]]
Rcpp::LogicalVector cpp_form_field_is_option_selected_handle(
    SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  if (ffi.form == nullptr) return Rcpp::LogicalVector();
  int n = FPDFAnnot_GetOptionCount(ffi.form, a);
  if (n <= 0) return Rcpp::LogicalVector();
  Rcpp::LogicalVector out(n);
  for (int i = 0; i < n; ++i) {
    out[i] = FPDFAnnot_IsOptionSelected(ffi.form, a, i) ? TRUE : FALSE;
  }
  return out;
}

// FPDF_ANNOT_AACTION_* codes that map to the four R-side names.
// These match the iteration in src/form_fields.cpp's bulk reader.
static const int kAdditionalActionEvents[4] = {
    FPDF_ANNOT_AACTION_KEY_STROKE,
    FPDF_ANNOT_AACTION_FORMAT,
    FPDF_ANNOT_AACTION_VALIDATE,
    FPDF_ANNOT_AACTION_CALCULATE
};

// [[Rcpp::export(name = "cpp_form_field_additional_actions_handle")]]
Rcpp::CharacterVector cpp_form_field_additional_actions_handle(
    SEXP annot_ptr, SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ff_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION a = ff_annot_from_ptr(annot_ptr);
  FFIGuard ffi(doc);
  Rcpp::CharacterVector out(4);
  out.attr("names") = Rcpp::CharacterVector::create(
      "key_stroke", "format", "validate", "calculate");
  if (ffi.form == nullptr) {
    for (int i = 0; i < 4; ++i) out[i] = "";
    return out;
  }
  for (int i = 0; i < 4; ++i) {
    unsigned long needed = FPDFAnnot_GetFormAdditionalActionJavaScript(
        ffi.form, a, kAdditionalActionEvents[i], nullptr, 0);
    if (needed <= 2) { out[i] = ""; continue; }
    std::vector<unsigned short> buf(needed / 2);
    FPDFAnnot_GetFormAdditionalActionJavaScript(
        ffi.form, a, kAdditionalActionEvents[i],
        reinterpret_cast<FPDF_WCHAR*>(buf.data()), needed);
    size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
    out[i] = pdfium_r::utf16le_to_utf8(buf.data(), wchars);
  }
  return out;
}
