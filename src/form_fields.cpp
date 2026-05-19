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

// Per-option "is currently selected" flags for combobox / listbox.
// Length matches read_form_options; empty for other field types.
Rcpp::LogicalVector read_option_selected(
    FPDF_FORMHANDLE form, FPDF_ANNOTATION annot) {
  int n = FPDFAnnot_GetOptionCount(form, annot);
  if (n <= 0) return Rcpp::LogicalVector();
  Rcpp::LogicalVector out(n);
  for (int i = 0; i < n; ++i) {
    out[i] = FPDFAnnot_IsOptionSelected(form, annot, i) ? TRUE : FALSE;
  }
  return out;
}

// Per-field-event JavaScript trigger strings. PDFium exposes four
// events keyed by the FPDF_ANNOT_AACTION_* enum (12=KEY_STROKE,
// 13=FORMAT, 14=VALIDATE, 15=CALCULATE). Returns a named character
// vector of length 4; empty string for events without a JS handler.
Rcpp::CharacterVector read_additional_actions_js(
    FPDF_FORMHANDLE form, FPDF_ANNOTATION annot) {
  const int events[] = {FPDF_ANNOT_AACTION_KEY_STROKE,
                         FPDF_ANNOT_AACTION_FORMAT,
                         FPDF_ANNOT_AACTION_VALIDATE,
                         FPDF_ANNOT_AACTION_CALCULATE};
  const char* names[] = {"key_stroke", "format", "validate", "calculate"};
  Rcpp::CharacterVector out(4);
  for (int i = 0; i < 4; ++i) {
    unsigned long needed = FPDFAnnot_GetFormAdditionalActionJavaScript(
        form, annot, events[i], nullptr, 0);
    if (needed <= 2) {
      out[i] = "";
      continue;
    }
    std::vector<unsigned short> buf(needed / 2);
    FPDFAnnot_GetFormAdditionalActionJavaScript(
        form, annot, events[i],
        reinterpret_cast<FPDF_WCHAR*>(buf.data()), needed);
    size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
    out[i] = pdfium_r::utf16le_to_utf8(buf.data(), wchars);
  }
  out.attr("names") = Rcpp::CharacterVector::create(
      names[0], names[1], names[2], names[3]);
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
        Rcpp::_["is_checked"]    = Rcpp::IntegerVector(),
        Rcpp::_["control_count"] = Rcpp::IntegerVector(),
        Rcpp::_["control_index"] = Rcpp::IntegerVector(),
        Rcpp::_["name"]          = Rcpp::CharacterVector(),
        Rcpp::_["alternate_name"] = Rcpp::CharacterVector(),
        Rcpp::_["value"]         = Rcpp::CharacterVector(),
        Rcpp::_["export_value"]  = Rcpp::CharacterVector(),
        Rcpp::_["bounds_left"]    = Rcpp::NumericVector(),
        Rcpp::_["bounds_bottom"]  = Rcpp::NumericVector(),
        Rcpp::_["bounds_right"]   = Rcpp::NumericVector(),
        Rcpp::_["bounds_top"]     = Rcpp::NumericVector(),
        Rcpp::_["options"]       = Rcpp::List(),
        Rcpp::_["is_option_selected"] = Rcpp::List(),
        Rcpp::_["additional_actions_js"] = Rcpp::List());
  }

  std::vector<int> page_nums;
  std::vector<int> field_types;
  std::vector<int> field_flags;
  std::vector<int> is_checked;  // 1=checked, 0=unchecked, -1=N/A
  std::vector<int> control_count;
  std::vector<int> control_index;
  std::vector<std::string> names;
  std::vector<std::string> alt_names;
  std::vector<std::string> values;
  std::vector<std::string> export_values;
  std::vector<double> lefts;
  std::vector<double> bottoms;
  std::vector<double> rights;
  std::vector<double> tops;
  Rcpp::List options;
  Rcpp::List is_option_selected;
  Rcpp::List additional_actions_js;

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
      // FPDFAnnot_IsChecked only returns meaningful values for
      // checkbox / radiobutton fields whose control is registered
      // in PDFium's ControlMap (PDFium keys the map by the field
      // dict pointer, which can mismatch the annot dict pointer
      // for hand-built PDFs). For everything else (and as a fallback
      // for those mismatches), we surface -1 here and let the R
      // wrapper infer from the field's value (PDFium reports
      // "Off" when no control is checked, the on-state name
      // otherwise — see CPDF_FormField::GetCheckValue).
      bool checkable = (ftype == FPDF_FORMFIELD_CHECKBOX ||
                         ftype == FPDF_FORMFIELD_RADIOBUTTON);
      if (checkable) {
        int rc = FPDFAnnot_IsChecked(form, annot) ? 1 : 0;
        is_checked.push_back(rc);
      } else {
        is_checked.push_back(-1);
      }
      // Control group bookkeeping. For radio button widgets the
      // field's /Kids array typically has N widgets and PDFium
      // tells us both the total count and this widget's 0-based
      // position via FPDFAnnot_GetFormControl*. For non-button
      // fields PDFium returns 1/0; we surface the raw integers
      // and let the R wrapper map negative-on-failure to NA.
      control_count.push_back(
          FPDFAnnot_GetFormControlCount(form, annot));
      control_index.push_back(
          FPDFAnnot_GetFormControlIndex(form, annot));
      names.push_back(
          read_form_string(form, annot, FPDFAnnot_GetFormFieldName));
      alt_names.push_back(read_form_string(
          form, annot, FPDFAnnot_GetFormFieldAlternateName));
      values.push_back(
          read_form_string(form, annot, FPDFAnnot_GetFormFieldValue));
      export_values.push_back(read_form_string(
          form, annot, FPDFAnnot_GetFormFieldExportValue));
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
      is_option_selected.push_back(read_option_selected(form, annot));
      additional_actions_js.push_back(
          read_additional_actions_js(form, annot));
      FPDFPage_CloseAnnot(annot);
    }
    FPDF_ClosePage(page);
  }
  FPDFDOC_ExitFormFillEnvironment(form);

  return Rcpp::List::create(
      Rcpp::_["page_num"]       = page_nums,
      Rcpp::_["field_type"]     = field_types,
      Rcpp::_["field_flags"]    = field_flags,
      Rcpp::_["is_checked"]     = is_checked,
      Rcpp::_["control_count"]  = control_count,
      Rcpp::_["control_index"]  = control_index,
      Rcpp::_["name"]           = names,
      Rcpp::_["alternate_name"] = alt_names,
      Rcpp::_["value"]          = values,
      Rcpp::_["export_value"]   = export_values,
      Rcpp::_["bounds_left"]    = lefts,
      Rcpp::_["bounds_bottom"]  = bottoms,
      Rcpp::_["bounds_right"]   = rights,
      Rcpp::_["bounds_top"]     = tops,
      Rcpp::_["options"]        = options,
      Rcpp::_["is_option_selected"] = is_option_selected,
      Rcpp::_["additional_actions_js"] = additional_actions_js);
}
