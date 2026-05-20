// pdfium R package — generic annotation dict probing + bridges to
// adjacent objects. Un-defers the Tier 3 readers we previously
// left to v0.2.0 because they didn't fit existing modules:
//
//   FPDFAnnot_GetValueType + GetStringValue + GetNumberValue
//                                     pdf_annot_dict_value()
//   FPDFAnnot_GetAP                   pdf_annot_appearance(annot, mode)
//   FPDFLink_GetLinkAtPoint +
//   FPDFLink_GetAnnot                 pdf_link_annot_at_point()
//   FPDFPageObj_GetMarkedContentID    pdf_obj_marked_content_id()
//   FPDFAnnot_GetFocusableSubtypes*   pdf_doc_focusable_subtypes()
//
// All accessors take the same handles the existing readers consume;
// no new S3 classes.

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_doc.h"
#include "fpdf_edit.h"
#include "fpdf_formfill.h"
#include "handle_validation.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT ap_doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

FPDF_PAGE ap_page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

FPDF_PAGEOBJECT ap_obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// Read an annotation-dict entry by key. Returns has_key + the
// FPDF_OBJECT_* value type + a typed value (string for STRING/NAME,
// number for NUMBER, NA otherwise). The caller specifies the
// page + annotation_index just like pdf_annotations().
// [[Rcpp::export(name = "cpp_annot_dict_value")]]
Rcpp::List cpp_annot_dict_value(SEXP page_ptr,
                                 int annot_index_zero,
                                 std::string key) {
  FPDF_PAGE page = ap_page_from_ptr(page_ptr);
  FPDF_ANNOTATION annot = FPDFPage_GetAnnot(page, annot_index_zero);
  if (annot == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["has_key"]      = false,
        Rcpp::_["value_type"]   = NA_INTEGER,
        Rcpp::_["value_string"] = Rcpp::CharacterVector::create(NA_STRING),
        Rcpp::_["value_number"] = NA_REAL);
  }
  bool has = FPDFAnnot_HasKey(annot, key.c_str()) != 0;
  if (!has) {
    FPDFPage_CloseAnnot(annot);
    return Rcpp::List::create(
        Rcpp::_["has_key"]      = false,
        Rcpp::_["value_type"]   = NA_INTEGER,
        Rcpp::_["value_string"] = Rcpp::CharacterVector::create(NA_STRING),
        Rcpp::_["value_number"] = NA_REAL);
  }
  int t = FPDFAnnot_GetValueType(annot, key.c_str());
  std::string val_string;
  bool got_string = false;
  double val_number = NA_REAL;
  if (t == FPDF_OBJECT_STRING || t == FPDF_OBJECT_NAME) {
    unsigned long needed =
        FPDFAnnot_GetStringValue(annot, key.c_str(), nullptr, 0);
    if (needed > 2) {
      std::vector<unsigned short> buf(needed / 2);
      FPDFAnnot_GetStringValue(
          annot, key.c_str(),
          reinterpret_cast<FPDF_WCHAR*>(buf.data()), needed);
      size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
      val_string = pdfium_r::utf16le_to_utf8(buf.data(), wchars);
      got_string = true;
    } else if (needed == 2) {
      // Empty string.
      val_string = std::string();
      got_string = true;
    }
  } else if (t == FPDF_OBJECT_NUMBER) {
    float f = 0.f;
    if (FPDFAnnot_GetNumberValue(annot, key.c_str(), &f)) {
      val_number = f;
    }
  }
  FPDFPage_CloseAnnot(annot);
  Rcpp::CharacterVector vs = got_string
      ? Rcpp::CharacterVector::create(val_string)
      : Rcpp::CharacterVector::create(NA_STRING);
  return Rcpp::List::create(
      Rcpp::_["has_key"]      = true,
      Rcpp::_["value_type"]   = t,
      Rcpp::_["value_string"] = vs,
      Rcpp::_["value_number"] = val_number);
}

// Read the annotation's appearance-stream content for the given
// appearance mode (Normal / Rollover / Down). Returns the appearance
// string PDFium reports — typically the `/AP` /N|/R|/D stream's
// content as a UTF-8 representation of its embedded "appearance
// string" form per the PDF spec. Empty string when no appearance is
// set for that mode.
// [[Rcpp::export(name = "cpp_annot_appearance")]]
std::string cpp_annot_appearance(SEXP page_ptr,
                                  int annot_index_zero,
                                  int appearance_mode) {
  FPDF_PAGE page = ap_page_from_ptr(page_ptr);
  FPDF_ANNOTATION annot = FPDFPage_GetAnnot(page, annot_index_zero);
  if (annot == nullptr) return std::string();
  unsigned long needed = FPDFAnnot_GetAP(
      annot,
      static_cast<FPDF_ANNOT_APPEARANCEMODE>(appearance_mode),
      nullptr, 0);
  if (needed <= 2) {
    FPDFPage_CloseAnnot(annot);
    return std::string();
  }
  std::vector<unsigned short> buf(needed / 2);
  FPDFAnnot_GetAP(annot,
                   static_cast<FPDF_ANNOT_APPEARANCEMODE>(appearance_mode),
                   buf.data(), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  std::string out = pdfium_r::utf16le_to_utf8(buf.data(), wchars);
  FPDFPage_CloseAnnot(annot);
  return out;
}

// Hit-test for a link at (x, y) and return the page-scoped 1-based
// annotation_index of the underlying link annotation, plus its
// z-order. Returns NA fields when no link is under the point.
// Companion to pdf_link_at_point() which surfaces action / dest
// details — this one is for callers that want to then call
// pdf_annot_dict_value() or pdf_annot_appearance() on the
// underlying annotation.
// [[Rcpp::export(name = "cpp_link_annot_at_point")]]
Rcpp::List cpp_link_annot_at_point(SEXP page_ptr, double x, double y) {
  FPDF_PAGE page = ap_page_from_ptr(page_ptr);
  FPDF_LINK link = FPDFLink_GetLinkAtPoint(page, x, y);
  if (link == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["found"]            = false,
        Rcpp::_["annotation_index"] = NA_INTEGER,
        Rcpp::_["z_order"]          = NA_INTEGER);
  }
  FPDF_ANNOTATION target = FPDFLink_GetAnnot(page, link);
  int z = FPDFLink_GetLinkZOrderAtPoint(page, x, y);
  int idx = -1;
  if (target != nullptr) {
    FS_RECTF t_rect;
    bool got_rect = FPDFAnnot_GetRect(target, &t_rect) != 0;
    int n = FPDFPage_GetAnnotCount(page);
    for (int i = 0; i < n; ++i) {
      FPDF_ANNOTATION cand = FPDFPage_GetAnnot(page, i);
      if (cand == nullptr) continue;
      bool match = (cand == target);
      if (!match && got_rect) {
        FS_RECTF c_rect;
        if (FPDFAnnot_GetRect(cand, &c_rect)) {
          match = (c_rect.left == t_rect.left &&
                   c_rect.right == t_rect.right &&
                   c_rect.top == t_rect.top &&
                   c_rect.bottom == t_rect.bottom &&
                   FPDFAnnot_GetSubtype(cand) ==
                       FPDFAnnot_GetSubtype(target));
        }
      }
      FPDFPage_CloseAnnot(cand);
      if (match) { idx = i + 1; break; }
    }
    FPDFPage_CloseAnnot(target);
  }
  return Rcpp::List::create(
      Rcpp::_["found"]            = true,
      Rcpp::_["annotation_index"] = (idx < 0) ? NA_INTEGER : idx,
      Rcpp::_["z_order"]          = (z < 0) ? NA_INTEGER : z);
}

// Direct marked-content ID for a page object (vs the full marks
// readout in pdf_obj_marks()). Returns NA when the object has no
// direct MCID. Wraps FPDFPageObj_GetMarkedContentID.
// [[Rcpp::export(name = "cpp_obj_marked_content_id")]]
int cpp_obj_marked_content_id(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = ap_obj_from_ptr(obj_ptr);
  int mcid = FPDFPageObj_GetMarkedContentID(obj);
  return mcid;  // -1 means "no MCID"; R wrapper maps to NA_integer_
}

// Form-fill module's "focusable subtypes" — the annotation types
// that should accept tab focus (widget is always focusable plus
// any subtypes the host has set). Wraps
// FPDFAnnot_GetFocusableSubtypesCount + FPDFAnnot_GetFocusableSubtypes.
// [[Rcpp::export(name = "cpp_doc_focusable_subtypes")]]
Rcpp::IntegerVector cpp_doc_focusable_subtypes(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = ap_doc_from_ptr(doc_ptr);
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) return Rcpp::IntegerVector();
  int n = FPDFAnnot_GetFocusableSubtypesCount(form);
  if (n <= 0) {
    FPDFDOC_ExitFormFillEnvironment(form);
    return Rcpp::IntegerVector();
  }
  std::vector<FPDF_ANNOTATION_SUBTYPE> codes(n);
  if (!FPDFAnnot_GetFocusableSubtypes(form, codes.data(),
                                       static_cast<size_t>(n))) {
    FPDFDOC_ExitFormFillEnvironment(form);
    return Rcpp::IntegerVector();
  }
  Rcpp::IntegerVector out(n);
  for (int i = 0; i < n; ++i) out[i] = static_cast<int>(codes[i]);
  FPDFDOC_ExitFormFillEnvironment(form);
  return out;
}
