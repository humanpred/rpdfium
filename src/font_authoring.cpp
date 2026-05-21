// pdfium R package — font loading for the page-authoring API.
//
// Three exports:
//   cpp_font_load_standard   — FPDFText_LoadStandardFont
//   cpp_font_load_truetype   — FPDFText_LoadFont (TrueType / Type1)
//   cpp_text_new_with_font   — FPDFPageObj_CreateTextObj
//
// All three return externalptrs whose `prot` slot pins the parent
// document (so the doc outlives the font / text obj). The font
// externalptr carries a finalizer that calls FPDFFont_Close;
// page objects (the text obj returned by CreateTextObj) inherit
// page lifetime so they have no finalizer, matching the existing
// path/rect creator conventions.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"
#include "utf16.h"

namespace {

inline FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

inline FPDF_PAGE page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

inline FPDF_FONT font_from_ptr(SEXP font_ptr) {
  return static_cast<FPDF_FONT>(
      pdfium_r::validate_handle(font_ptr, "Font",
                                  /*require_prot_alive=*/true));
}

// Finalizer for pdfium_font externalptr. PDFium's FPDFFont_Close
// releases the font (it stays referenced by any text objects that
// already used it; this just drops the embedder's hold).
void font_finalizer(SEXP font_ptr) {
  if (TYPEOF(font_ptr) != EXTPTRSXP) return;
  FPDF_FONT font = static_cast<FPDF_FONT>(R_ExternalPtrAddr(font_ptr));
  if (font == nullptr) return;
  FPDFFont_Close(font);
  R_ClearExternalPtr(font_ptr);
}

}  // namespace

// [[Rcpp::export(name = "cpp_font_load_standard")]]
SEXP cpp_font_load_standard(SEXP doc_ptr, std::string font_name) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_FONT font = FPDFText_LoadStandardFont(doc, font_name.c_str());
  if (font == nullptr) {
    Rcpp::stop(
        "FPDFText_LoadStandardFont('%s') returned NULL. Valid names "
        "are the 14 PDF standard fonts (e.g. 'Helvetica', "
        "'Helvetica-Bold', 'Times-Roman', 'Courier').",
        font_name.c_str());
  }
  SEXP ext = PROTECT(R_MakeExternalPtr(font, R_NilValue, doc_ptr));
  R_RegisterCFinalizerEx(ext, font_finalizer, TRUE);
  UNPROTECT(1);
  return ext;
}

// [[Rcpp::export(name = "cpp_font_load_truetype")]]
SEXP cpp_font_load_truetype(SEXP doc_ptr, Rcpp::RawVector font_data,
                              int font_type, bool cid) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  const std::uint8_t* data =
      font_data.size() > 0
          ? reinterpret_cast<const std::uint8_t*>(&font_data[0])
          : nullptr;
  FPDF_FONT font = FPDFText_LoadFont(
      doc, data, static_cast<std::uint32_t>(font_data.size()),
      font_type, cid ? 1 : 0);
  if (font == nullptr) {
    Rcpp::stop(
        "FPDFText_LoadFont returned NULL. Confirm the bytes are a "
        "valid %s font.",
        font_type == 1 ? "Type1" : "TrueType");
  }
  SEXP ext = PROTECT(R_MakeExternalPtr(font, R_NilValue, doc_ptr));
  R_RegisterCFinalizerEx(ext, font_finalizer, TRUE);
  UNPROTECT(1);
  return ext;
}

// [[Rcpp::export(name = "cpp_font_close")]]
void cpp_font_close(SEXP font_ptr) {
  // Idempotent — finalizer-style close. Match pdf_doc_close's
  // "second call is a no-op" contract.
  if (TYPEOF(font_ptr) != EXTPTRSXP) return;
  FPDF_FONT font = static_cast<FPDF_FONT>(R_ExternalPtrAddr(font_ptr));
  if (font == nullptr) return;
  FPDFFont_Close(font);
  R_ClearExternalPtr(font_ptr);
}

// [[Rcpp::export(name = "cpp_text_new_with_font")]]
SEXP cpp_text_new_with_font(SEXP doc_ptr, SEXP page_ptr,
                              SEXP font_ptr, double font_size,
                              std::string text_utf8,
                              double x, double y) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_FONT font = font_from_ptr(font_ptr);

  FPDF_PAGEOBJECT text_obj = FPDFPageObj_CreateTextObj(
      doc, font, static_cast<float>(font_size));
  if (text_obj == nullptr) {
    Rcpp::stop("FPDFPageObj_CreateTextObj returned NULL.");
  }
  if (!text_utf8.empty()) {
    std::vector<unsigned short> utf16 =
        pdfium_r::utf8_to_utf16le_nul(text_utf8);
    if (!FPDFText_SetText(
            text_obj,
            reinterpret_cast<FPDF_WIDESTRING>(utf16.data()))) {
      FPDFPageObj_Destroy(text_obj);
      Rcpp::stop("FPDFText_SetText failed on the new text object.");
    }
  }
  // Identity scale + translate (same convention as cpp_text_new).
  FPDFPageObj_Transform(text_obj, 1, 0, 0, 1,
                         static_cast<float>(x),
                         static_cast<float>(y));
  FPDFPage_InsertObject(page, text_obj);
  return R_MakeExternalPtr(text_obj, R_NilValue, page_ptr);
}
