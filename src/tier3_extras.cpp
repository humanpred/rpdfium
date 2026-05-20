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
#include "utf16.h"

namespace {

FPDF_DOCUMENT t3_doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

FPDF_PAGE t3_page_from_ptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

FPDF_PAGEOBJECT t3_obj_from_ptr(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page object.");
  }
  FPDF_PAGEOBJECT obj =
      static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) Rcpp::stop("Page object handle is closed.");
  return obj;
}

// Convert an FPDF_BITMAP (BGRA / BGR / Gray) to R's nativeRaster
// (ABGR packed integers, row-major). Mirrors the conversion the
// rendering / image modules use. Closes the bitmap.
SEXP fpdf_bitmap_to_native(FPDF_BITMAP bmp) {
  if (bmp == nullptr) return R_NilValue;
  int w = FPDFBitmap_GetWidth(bmp);
  int h = FPDFBitmap_GetHeight(bmp);
  int stride = FPDFBitmap_GetStride(bmp);
  int format = FPDFBitmap_GetFormat(bmp);
  const uint8_t* src =
      static_cast<const uint8_t*>(FPDFBitmap_GetBuffer(bmp));
  Rcpp::IntegerMatrix m(h, w);
  for (int y = 0; y < h; ++y) {
    const uint8_t* row = src + y * stride;
    for (int x = 0; x < w; ++x) {
      uint8_t r = 0, g = 0, b = 0, a = 0xFF;
      switch (format) {
        case FPDFBitmap_BGRA:
          b = row[x * 4 + 0];
          g = row[x * 4 + 1];
          r = row[x * 4 + 2];
          a = row[x * 4 + 3];
          break;
        case FPDFBitmap_BGRx:
          b = row[x * 4 + 0];
          g = row[x * 4 + 1];
          r = row[x * 4 + 2];
          a = 0xFF;
          break;
        case FPDFBitmap_BGR:
          b = row[x * 3 + 0];
          g = row[x * 3 + 1];
          r = row[x * 3 + 2];
          a = 0xFF;
          break;
        case FPDFBitmap_Gray:
          b = g = r = row[x];
          a = 0xFF;
          break;
        default:
          break;
      }
      uint32_t abgr = (static_cast<uint32_t>(a) << 24) |
                      (static_cast<uint32_t>(b) << 16) |
                      (static_cast<uint32_t>(g) << 8)  |
                       static_cast<uint32_t>(r);
      m(y, x) = static_cast<int>(abgr);
    }
  }
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
// [[Rcpp::export(name = "cpp_attachment_dict_value")]]
Rcpp::List cpp_attachment_dict_value(SEXP doc_ptr, int index_zero,
                                      std::string key) {
  FPDF_DOCUMENT doc = t3_doc_from_ptr(doc_ptr);
  FPDF_ATTACHMENT att = FPDFDoc_GetAttachment(doc, index_zero);
  if (att == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["has_key"]    = false,
        Rcpp::_["value_type"] = NA_INTEGER,
        Rcpp::_["value"]      = Rcpp::CharacterVector::create(NA_STRING));
  }
  bool has = FPDFAttachment_HasKey(att, key.c_str()) != 0;
  if (!has) {
    return Rcpp::List::create(
        Rcpp::_["has_key"]    = false,
        Rcpp::_["value_type"] = NA_INTEGER,
        Rcpp::_["value"]      = Rcpp::CharacterVector::create(NA_STRING));
  }
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

// Translate a 0-based char_index on the page's text page to the
// 1-based page-object index of the text run that contains it.
// Returns -1 when the char is not associated with a page object
// (e.g. PDFium-synthesised whitespace).
// [[Rcpp::export(name = "cpp_text_char_obj_index")]]
int cpp_text_char_obj_index(SEXP page_ptr, int char_index_zero) {
  FPDF_PAGE page = t3_page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  FPDF_PAGEOBJECT target = FPDFText_GetTextObject(tp, char_index_zero);
  FPDFText_ClosePage(tp);
  if (target == nullptr) return -1;
  int n = FPDFPage_CountObjects(page);
  for (int i = 0; i < n; ++i) {
    FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page, i);
    if (obj == target) return i + 1;
  }
  return -1;
}
