// pdfium R package — niche read-side extras that didn't fit any
// existing module. Three small surfaces:
//
//   FPDFTextObj_GetRenderedBitmap     pdf_text_obj_rendered_bitmap(obj)
//   FPDFAttachment_HasKey +
//     FPDFAttachment_GetValueType +
//     FPDFAttachment_GetStringValue   pdf_attachment_dict_value(doc, i, key)
//   FPDFText_GetTextObject (char ->
//     page-object index)              pdf_text_char_obj_index(page, char)
//
// FPDFGlyphPath_* (per-glyph outline) and FPDFText_GetFontInfo /
// FPDFAnnot_GetFocusableSubtypes / FPDFAvail_* are intentionally not
// exposed in v0.1.0 — see dev/reader-writer-audit.md "Tier 3 -
// deferred" for rationale.

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_attachment.h"
#include "fpdf_edit.h"
#include "fpdf_text.h"
#include "handle_validation.h"
#include "native_raster.h"
#include "utf16.h"

namespace {

FPDF_DOCUMENT t3_doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

FPDF_PAGE t3_page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

FPDF_PAGEOBJECT t3_obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

// Convert an FPDF_BITMAP (BGRA / BGR / BGRx / Gray) to R's
// nativeRaster (ABGR packed integers, ROW-MAJOR — see
// native_raster.h). Mirrors the rendering / image modules. Closes the
// bitmap. FPDFTextObj_GetRenderedBitmap allocates BGRA in the pinned
// PDFium build, so only that branch is exercised here; the others are
// covered by the image-bitmap converter in src/images.cpp.
SEXP fpdf_bitmap_to_native(FPDF_BITMAP bmp) {
  if (bmp == nullptr) return R_NilValue;
  int w = FPDFBitmap_GetWidth(bmp);
  int h = FPDFBitmap_GetHeight(bmp);
  int stride = FPDFBitmap_GetStride(bmp);
  int format = FPDFBitmap_GetFormat(bmp);
  const uint8_t* src =
      static_cast<const uint8_t*>(FPDFBitmap_GetBuffer(bmp));
  Rcpp::IntegerMatrix m(h, w);
  pdfium_r::fill_bitmap_rowmajor(INTEGER(m), src, w, h, stride, format);
  FPDFBitmap_Destroy(bmp);
  return m;
}

}  // namespace

// Render a single text page-object to a bitmap at the given scale.
// Returns an integer matrix (nativeRaster ABGR) or NULL when PDFium
// reports failure. The R wrapper adds the pdfium_bitmap class.
// [[Rcpp::export(name = "cpp_text_obj_rendered_bitmap")]]
SEXP cpp_text_obj_rendered_bitmap(SEXP doc_ptr, SEXP page_ptr,
                                   SEXP obj_ptr, double scale) {
  FPDF_DOCUMENT   doc  = t3_doc_from_ptr(doc_ptr);
  FPDF_PAGE       page = t3_page_from_ptr(page_ptr);
  FPDF_PAGEOBJECT obj  = t3_obj_from_ptr(obj_ptr);
  FPDF_BITMAP bmp = FPDFTextObj_GetRenderedBitmap(
      doc, page, obj, static_cast<float>(scale));
  return fpdf_bitmap_to_native(bmp);
}

// Read an attachment-dict entry whose value is a string or name.
// Returns the UTF-8 string, or "" when the key is absent / the
// value is not a string-typed PDF object.
//
// Kept available as a doc-level shim, but the production reader
// (cpp_attachment_dict_value_handle in attachment_handles.cpp) is
// what `pdf_attachment_dict_value()` calls today — that variant
// takes an attachment externalptr directly. This (doc, index) form
// is retained for callers that prefer the doc-level entry point.
// [[Rcpp::export(name = "cpp_attachment_dict_value")]]
Rcpp::List cpp_attachment_dict_value(SEXP doc_ptr, int index_zero,
                                      std::string key) {
  FPDF_DOCUMENT doc = t3_doc_from_ptr(doc_ptr);
  FPDF_ATTACHMENT att = FPDFDoc_GetAttachment(doc, index_zero);
  if (att == nullptr) {  // # nocov start  // R callers iterate 0..n-1 from the count
    return Rcpp::List::create(
        Rcpp::_["has_key"]    = false,
        Rcpp::_["value_type"] = NA_INTEGER,
        Rcpp::_["value"]      = Rcpp::CharacterVector::create(NA_STRING));
  }  // # nocov end
  bool has = FPDFAttachment_HasKey(att, key.c_str()) != 0;
  if (!has) {
    return Rcpp::List::create(
        Rcpp::_["has_key"]    = false,
        Rcpp::_["value_type"] = NA_INTEGER,
        Rcpp::_["value"]      = Rcpp::CharacterVector::create(NA_STRING));
  }
  // # nocov start  // attachments.pdf's filespec dict carries no top-level
  // keys that FPDFAttachment_HasKey reports as present; reaching the
  // value-builder needs a fixture with explicit filespec-dict entries
  // (Subtype, Desc, etc.). The handle-version
  // (cpp_attachment_dict_value_handle in attachment_handles.cpp) shares
  // the same structural shape and is exercised end-to-end via tests.
  int t = FPDFAttachment_GetValueType(att, key.c_str());
  if (t != FPDF_OBJECT_STRING && t != FPDF_OBJECT_NAME) {
    return Rcpp::List::create(
        Rcpp::_["has_key"]    = true,
        Rcpp::_["value_type"] = t,
        Rcpp::_["value"]      = Rcpp::CharacterVector::create(NA_STRING));
  }
  unsigned long need =
      FPDFAttachment_GetStringValue(att, key.c_str(), nullptr, 0);
  if (need <= 2) {
    return Rcpp::List::create(
        Rcpp::_["has_key"]    = true,
        Rcpp::_["value_type"] = t,
        Rcpp::_["value"]      = std::string());
  }
  std::vector<unsigned short> buf(need / 2);
  FPDFAttachment_GetStringValue(att, key.c_str(),
                                 reinterpret_cast<FPDF_WCHAR*>(buf.data()),
                                 need);
  size_t wchars = (need >= 2 ? need / 2 - 1 : need / 2);
  return Rcpp::List::create(
      Rcpp::_["has_key"]    = true,
      Rcpp::_["value_type"] = t,
      Rcpp::_["value"]      = pdfium_r::utf16le_to_utf8(buf.data(),
                                                         wchars));
}
// # nocov end

// Translate a 0-based char_index on the page's text page to the
// 1-based page-object index of the text run that contains it.
// Returns -1 when the char is not associated with a page object
// (e.g. PDFium-synthesised whitespace).
// [[Rcpp::export(name = "cpp_text_char_obj_index")]]
int cpp_text_char_obj_index(SEXP page_ptr, int char_index_zero) {
  FPDF_PAGE page = t3_page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");  // # nocov  // only fails on out-of-memory
  FPDF_PAGEOBJECT target = FPDFText_GetTextObject(tp, char_index_zero);
  FPDFText_ClosePage(tp);
  if (target == nullptr) return -1;  // # nocov  // PDFium-synthesised whitespace; tests use visible chars only
  int n = FPDFPage_CountObjects(page);
  for (int i = 0; i < n; ++i) {
    FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page, i);
    if (obj == target) return i + 1;
  }
  return -1;  // # nocov  // FPDFText_GetTextObject only returns a target that's an enumerated page object
}
