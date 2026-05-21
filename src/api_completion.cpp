// pdfium R package — v0.1.0 "complete the relevant PDFium surface" pass.
//
// This file collects single-call wrappers that pair with already-shipped
// readers / writers and were the last remaining wrapping gaps before
// CRAN submission. Functions live here rather than in their topical
// neighbours so the v0.1.0-completion diff stays bisectable.
//
// Phase A — simple readers + getters (text low-level geometry, page
// coordinate conversions, page metadata probes, font-data extraction,
// charcode-driven text authoring, mark blob/remove). Phases B–G land
// in sibling files (annotation authoring, clip-path, form-XObjects,
// image-bitmap, custom-load, system fonts).

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_doc.h"
#include "fpdf_edit.h"
#include "fpdf_formfill.h"
#include "fpdf_text.h"
#include "handle_validation.h"

namespace {

inline FPDF_DOCUMENT acomp_doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

inline FPDF_PAGE acomp_page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

inline FPDF_PAGEOBJECT acomp_obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

inline FPDF_BOOKMARK acomp_bookmark_from_ptr(SEXP bm_ptr) {
  return static_cast<FPDF_BOOKMARK>(
      pdfium_r::validate_handle(bm_ptr, "Bookmark",
                                  /*require_prot_alive=*/true));
}

inline FPDF_ANNOTATION acomp_annot_from_ptr(SEXP annot_ptr) {
  return static_cast<FPDF_ANNOTATION>(
      pdfium_r::validate_handle(annot_ptr, "Annotation",
                                  /*require_prot_alive=*/true));
}

inline FPDF_FONT acomp_font_from_ptr(SEXP font_ptr) {
  return static_cast<FPDF_FONT>(
      pdfium_r::validate_handle(font_ptr, "Font",
                                  /*require_prot_alive=*/true));
}

}  // namespace

// ---------------------------------------------------------------------------
// Bookmark child count — pairs with the pre-order walk in
// cpp_bookmark_handles. Useful for incremental tree exploration without
// re-walking the whole outline.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_bookmark_child_count")]]
int cpp_bookmark_child_count(SEXP bm_ptr) {
  FPDF_BOOKMARK bm = acomp_bookmark_from_ptr(bm_ptr);
  return FPDFBookmark_GetCount(bm);
}

// ---------------------------------------------------------------------------
// Doc-wide form type — distinguishes the four form flavours PDFium
// reports (NONE / ACRO_FORM / XFA_FULL / XFA_FOREGROUND). Surfaced as an
// integer; the R wrapper maps to the name.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_doc_form_type")]]
int cpp_doc_form_type(SEXP doc_ptr) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  return FPDF_GetFormType(doc);
}

// ---------------------------------------------------------------------------
// Page transparency check.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_page_has_transparency")]]
bool cpp_page_has_transparency(SEXP page_ptr) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  return FPDFPage_HasTransparency(page) != 0;
}

// ---------------------------------------------------------------------------
// Page bounding box (cropbox intersected with mediabox, per PDFium docs).
// Returns NA_REAL fields on failure.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_page_bounding_box")]]
Rcpp::NumericVector cpp_page_bounding_box(SEXP page_ptr) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FS_RECTF r;
  if (!FPDF_GetPageBoundingBox(page, &r)) {
    return Rcpp::NumericVector::create(
      Rcpp::_["left"] = NA_REAL, Rcpp::_["bottom"] = NA_REAL,
      Rcpp::_["right"] = NA_REAL, Rcpp::_["top"] = NA_REAL);
  }
  return Rcpp::NumericVector::create(
    Rcpp::_["left"] = r.left, Rcpp::_["bottom"] = r.bottom,
    Rcpp::_["right"] = r.right, Rcpp::_["top"] = r.top);
}

// ---------------------------------------------------------------------------
// Transform every annotation on a page in one shot. Useful for the
// "shift all annotations on this page" pattern.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_page_transform_annots")]]
void cpp_page_transform_annots(SEXP page_ptr,
                                double a, double b, double c,
                                double d, double e, double f) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FPDFPage_TransformAnnots(page, a, b, c, d, e, f);
}

// ---------------------------------------------------------------------------
// Annotation handle → page-relative index. -1 if not found. Pairs with
// the index-driven path so an annot freshly returned from
// pdf_annot_new() can be located in the page's annot list.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_page_annot_index")]]
int cpp_page_annot_index(SEXP page_ptr, SEXP annot_ptr) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  return FPDFPage_GetAnnotIndex(page, annot);
}

// ---------------------------------------------------------------------------
// Device ↔ page coordinate conversion. PDFium uses these for viewers;
// for batch workflows they're useful when a downstream consumer
// reports pixel coordinates that need to be mapped back to PDF points
// (or vice versa) given a rendering window.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_device_to_page")]]
Rcpp::NumericVector cpp_device_to_page(SEXP page_ptr,
                                        int start_x, int start_y,
                                        int size_x, int size_y,
                                        int rotate,
                                        int device_x, int device_y) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  double px = 0.0, py = 0.0;
  if (!FPDF_DeviceToPage(page, start_x, start_y, size_x, size_y,
                          rotate, device_x, device_y, &px, &py)) {
    return Rcpp::NumericVector::create(NA_REAL, NA_REAL);
  }
  return Rcpp::NumericVector::create(Rcpp::_["x"] = px,
                                      Rcpp::_["y"] = py);
}

// [[Rcpp::export(name = "cpp_page_to_device")]]
Rcpp::IntegerVector cpp_page_to_device(SEXP page_ptr,
                                        int start_x, int start_y,
                                        int size_x, int size_y,
                                        int rotate,
                                        double page_x, double page_y) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  int dx = 0, dy = 0;
  if (!FPDF_PageToDevice(page, start_x, start_y, size_x, size_y,
                          rotate, page_x, page_y, &dx, &dy)) {
    return Rcpp::IntegerVector::create(NA_INTEGER, NA_INTEGER);
  }
  return Rcpp::IntegerVector::create(Rcpp::_["x"] = dx,
                                      Rcpp::_["y"] = dy);
}

// ---------------------------------------------------------------------------
// Text rectangle iteration: cpp_text_count_rects pre-caches PDFium's
// rect layout for a character range; cpp_text_rects walks the cached
// rects and returns a (rect_index, left, top, right, bottom) tibble.
// Single-call wrapping (count + per-rect getter) so the R side gets a
// ready-made data frame.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_text_rects")]]
Rcpp::List cpp_text_rects(SEXP page_ptr, int start_index, int count) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  int n = FPDFText_CountRects(tp, start_index, count);
  if (n < 0) n = 0;
  Rcpp::NumericVector left(n), top(n), right(n), bottom(n);
  for (int i = 0; i < n; ++i) {
    double l = 0, t = 0, r = 0, b = 0;
    if (FPDFText_GetRect(tp, i, &l, &t, &r, &b)) {
      left[i] = l; top[i] = t; right[i] = r; bottom[i] = b;
    } else {
      left[i] = NA_REAL; top[i] = NA_REAL;
      right[i] = NA_REAL; bottom[i] = NA_REAL;
    }
  }
  FPDFText_ClosePage(tp);
  return Rcpp::List::create(
    Rcpp::_["left"]   = left,
    Rcpp::_["top"]    = top,
    Rcpp::_["right"]  = right,
    Rcpp::_["bottom"] = bottom);
}

// ---------------------------------------------------------------------------
// Extract text inside a rectangle. Two-pass: ask for needed buffer
// length (in UTF-16 code units), then fill.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_text_bounded")]]
std::string cpp_text_bounded(SEXP page_ptr, double left, double top,
                              double right, double bottom) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  // First pass: 0-buffer probe returns the count of UTF-16 code units
  // including a trailing NUL.
  int need = FPDFText_GetBoundedText(tp, left, top, right, bottom,
                                       nullptr, 0);
  if (need <= 1) {
    FPDFText_ClosePage(tp);
    return std::string();
  }
  std::vector<unsigned short> buf(need);
  FPDFText_GetBoundedText(tp, left, top, right, bottom, buf.data(),
                            need);
  FPDFText_ClosePage(tp);
  // Convert UTF-16 → UTF-8 inline. Mirrors utf16.h's
  // utf16le_nul_to_utf8 but inlined for the simple case.
  std::string out;
  out.reserve(static_cast<std::size_t>(need));
  for (int i = 0; i + 1 < need; ++i) {
    unsigned int cp = buf[i];
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 2 < need) {
      unsigned int low = buf[i + 1];
      if (low >= 0xDC00 && low <= 0xDFFF) {
        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
        ++i;
      }
    }
    if (cp < 0x80) {
      out.push_back(static_cast<char>(cp));
    } else if (cp < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Per-character matrix / angle / font weight. Returned as flat
// vectors so the R wrapper can attach them as columns to
// pdf_text_chars() output.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_text_char_geometry")]]
Rcpp::List cpp_text_char_geometry(SEXP page_ptr) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  int n = FPDFText_CountChars(tp);
  if (n < 0) n = 0;
  // 6-column matrix for the (a, b, c, d, e, f) per character.
  Rcpp::NumericMatrix mat(n, 6);
  Rcpp::NumericVector angle(n);
  Rcpp::IntegerVector weight(n);
  for (int i = 0; i < n; ++i) {
    FS_MATRIX m{};
    if (FPDFText_GetMatrix(tp, i, &m)) {
      mat(i, 0) = m.a; mat(i, 1) = m.b;
      mat(i, 2) = m.c; mat(i, 3) = m.d;
      mat(i, 4) = m.e; mat(i, 5) = m.f;
    } else {
      mat(i, 0) = NA_REAL; mat(i, 1) = NA_REAL;
      mat(i, 2) = NA_REAL; mat(i, 3) = NA_REAL;
      mat(i, 4) = NA_REAL; mat(i, 5) = NA_REAL;
    }
    float deg = FPDFText_GetCharAngle(tp, i);
    angle[i] = (deg < 0) ? NA_REAL : static_cast<double>(deg);
    int w = FPDFText_GetFontWeight(tp, i);
    weight[i] = (w < 0) ? NA_INTEGER : w;
  }
  FPDFText_ClosePage(tp);
  return Rcpp::List::create(
    Rcpp::_["matrix"] = mat,
    Rcpp::_["angle"]  = angle,
    Rcpp::_["weight"] = weight);
}

// ---------------------------------------------------------------------------
// Page-object dash phase setter — fine-grained complement to
// pdf_path_set_dash() which sets array + phase together.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_obj_set_dash_phase")]]
bool cpp_obj_set_dash_phase(SEXP obj_ptr, double phase) {
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  return FPDFPageObj_SetDashPhase(obj, static_cast<float>(phase)) != 0;
}

// ---------------------------------------------------------------------------
// Page-object content-mark blob / remove operations. Index-driven for
// parallelism with the existing per-mark accessors.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_obj_mark_remove_param")]]
bool cpp_obj_mark_remove_param(SEXP obj_ptr, int mark_index,
                                std::string key) {
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  FPDF_PAGEOBJECTMARK mark = FPDFPageObj_GetMark(obj, mark_index);
  if (mark == nullptr) {
    Rcpp::stop("FPDFPageObj_GetMark returned NULL for mark index %d",
               mark_index);
  }
  return FPDFPageObjMark_RemoveParam(obj, mark, key.c_str()) != 0;
}

// [[Rcpp::export(name = "cpp_obj_mark_set_blob")]]
bool cpp_obj_mark_set_blob(SEXP doc_ptr, SEXP obj_ptr, int mark_index,
                            std::string key, Rcpp::RawVector value) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  FPDF_PAGEOBJECTMARK mark = FPDFPageObj_GetMark(obj, mark_index);
  if (mark == nullptr) {
    Rcpp::stop("FPDFPageObj_GetMark returned NULL for mark index %d",
               mark_index);
  }
  const unsigned char* data =
      value.size() > 0
          ? reinterpret_cast<const unsigned char*>(&value[0])
          : nullptr;
  return FPDFPageObjMark_SetBlobParam(
      doc, obj, mark, key.c_str(),
      data, static_cast<unsigned long>(value.size())) != 0;
}

// ---------------------------------------------------------------------------
// Font data extraction — useful for round-tripping an embedded font
// from one PDF to another, or piping into systemfonts /
// fontmgr for inspection. Two-pass buffer pattern.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_font_data")]]
Rcpp::RawVector cpp_font_data(SEXP font_ptr) {
  FPDF_FONT font = acomp_font_from_ptr(font_ptr);
  std::size_t need = 0;
  if (!FPDFFont_GetFontData(font, nullptr, 0, &need) || need == 0) {
    return Rcpp::RawVector(0);
  }
  Rcpp::RawVector out(need);
  std::size_t got = 0;
  if (!FPDFFont_GetFontData(font, out.begin(), need, &got)) {
    return Rcpp::RawVector(0);
  }
  if (got != need) {
    // Truncate to actual bytes returned.
    Rcpp::RawVector trim(got);
    std::copy_n(out.begin(), got, trim.begin());
    return trim;
  }
  return out;
}

// ---------------------------------------------------------------------------
// CID Type 2 font loading — for embedding TrueType fonts as CID-keyed
// (composite) glyph stores with explicit ToUnicode CMap + CID-to-GID
// mapping. Distinct from FPDFText_LoadFont (which we already wrap)
// because the CIDType2 variant exposes the mapping arguments PDFium
// otherwise generates by default.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_font_load_cidtype2")]]
SEXP cpp_font_load_cidtype2(SEXP doc_ptr, Rcpp::RawVector font_data,
                              std::string to_unicode_cmap,
                              Rcpp::RawVector cid_to_gid) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  const std::uint8_t* fd =
      font_data.size() > 0
          ? reinterpret_cast<const std::uint8_t*>(&font_data[0])
          : nullptr;
  const std::uint8_t* cgd =
      cid_to_gid.size() > 0
          ? reinterpret_cast<const std::uint8_t*>(&cid_to_gid[0])
          : nullptr;
  const char* cmap_arg =
      to_unicode_cmap.empty() ? nullptr : to_unicode_cmap.c_str();
  FPDF_FONT font = FPDFText_LoadCidType2Font(
      doc, fd, static_cast<std::uint32_t>(font_data.size()),
      cmap_arg, cgd,
      static_cast<std::uint32_t>(cid_to_gid.size()));
  if (font == nullptr) {
    Rcpp::stop("FPDFText_LoadCidType2Font returned NULL — check the "
               "TTF bytes, ToUnicode CMap, and CID-to-GID map sizes.");
  }
  SEXP ext = PROTECT(R_MakeExternalPtr(font, R_NilValue, doc_ptr));
  // Reuse the font_authoring.cpp finalizer indirectly: we re-register
  // a small lambda-equivalent that calls FPDFFont_Close.
  R_RegisterCFinalizerEx(
      ext,
      [](SEXP p) {
        if (TYPEOF(p) != EXTPTRSXP) return;
        FPDF_FONT f = static_cast<FPDF_FONT>(R_ExternalPtrAddr(p));
        if (f == nullptr) return;
        FPDFFont_Close(f);
        R_ClearExternalPtr(p);
      },
      static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ext;
}

// ---------------------------------------------------------------------------
// Set explicit glyph charcodes on an existing text object. Unlike
// FPDFText_SetText (which UTF-8 → glyph via the font's cmap), this
// takes raw charcodes and bypasses cmap resolution — useful when the
// font's encoding is custom or when the embedder already has the codes.
// ---------------------------------------------------------------------------
// [[Rcpp::export(name = "cpp_text_set_charcodes")]]
bool cpp_text_set_charcodes(SEXP obj_ptr,
                              Rcpp::IntegerVector charcodes) {
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  // PDFium's API takes uint32_t* — copy into a buffer because R's
  // INTSXP is signed int.
  std::vector<std::uint32_t> codes(charcodes.size());
  for (R_xlen_t i = 0; i < charcodes.size(); ++i) {
    int v = charcodes[i];
    if (v < 0) {
      Rcpp::stop("charcodes[%d] is negative; charcodes are unsigned",
                 static_cast<int>(i + 1));
    }
    codes[i] = static_cast<std::uint32_t>(v);
  }
  return FPDFText_SetCharcodes(
      obj, codes.data(),
      static_cast<std::size_t>(charcodes.size())) != 0;
}
