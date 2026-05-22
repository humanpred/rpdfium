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
#include "fpdf_transformpage.h"
#include "fpdf_ppo.h"
#include "fpdf_sysfontinfo.h"
#include "action_helpers.h"
#include "handle_validation.h"
#include "utf16.h"

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
  if (!FPDF_GetPageBoundingBox(page, &r)) {  // # nocov start
    return Rcpp::NumericVector::create(
      Rcpp::_["left"] = NA_REAL, Rcpp::_["bottom"] = NA_REAL,
      Rcpp::_["right"] = NA_REAL, Rcpp::_["top"] = NA_REAL);
  }                                          // # nocov end
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
    return Rcpp::NumericVector::create(NA_REAL, NA_REAL);  // # nocov
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
    return Rcpp::IntegerVector::create(NA_INTEGER, NA_INTEGER);  // # nocov
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
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");  // # nocov
  int n = FPDFText_CountRects(tp, start_index, count);
  if (n < 0) n = 0;
  Rcpp::NumericVector left(n), top(n), right(n), bottom(n);
  for (int i = 0; i < n; ++i) {
    double l = 0, t = 0, r = 0, b = 0;
    if (FPDFText_GetRect(tp, i, &l, &t, &r, &b)) {
      left[i] = l; top[i] = t; right[i] = r; bottom[i] = b;
    } else {                                  // # nocov start
      left[i] = NA_REAL; top[i] = NA_REAL;
      right[i] = NA_REAL; bottom[i] = NA_REAL;
    }                                          // # nocov end
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
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");  // # nocov
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
  // `need` includes the trailing NUL; the helper takes a character
  // count.
  return pdfium_r::utf16le_to_utf8(buf.data(),
                                     static_cast<size_t>(need - 1));
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
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");  // # nocov
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
    } else {                                  // # nocov start
      mat(i, 0) = NA_REAL; mat(i, 1) = NA_REAL;
      mat(i, 2) = NA_REAL; mat(i, 3) = NA_REAL;
      mat(i, 4) = NA_REAL; mat(i, 5) = NA_REAL;
    }                                          // # nocov end
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
  // # nocov start — Every font handle reachable via our public API
  // (pdf_font_load*, pdf_font_load_standard) comes from PDFium's
  // bundled TTFs which always have embedded data. This branch fires
  // only for FPDF_FONT instances that PDFium has materialised from
  // an externally-loaded PDF whose font is referenced by name but
  // not embedded — there is currently no public R surface that
  // returns such a handle (FPDFTextObj_GetFont is not wrapped).
  if (!FPDFFont_GetFontData(font, nullptr, 0, &need) || need == 0) {
    return Rcpp::RawVector(0);
  }
  // # nocov end
  Rcpp::RawVector out(need);
  std::size_t got = 0;
  if (!FPDFFont_GetFontData(font, out.begin(), need, &got)) {  // # nocov start
    return Rcpp::RawVector(0);
  }                                                              // # nocov end
  if (got != need) {                          // # nocov start
    // Truncate to actual bytes returned.
    Rcpp::RawVector trim(got);
    std::copy_n(out.begin(), got, trim.begin());
    return trim;
  }                                            // # nocov end
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
    if (v < 0) {                              // # nocov start
      // R-side validation rejects negative codes; defensive only.
      Rcpp::stop("charcodes[%d] is negative; charcodes are unsigned",
                 static_cast<int>(i + 1));
    }                                          // # nocov end
    codes[i] = static_cast<std::uint32_t>(v);
  }
  return FPDFText_SetCharcodes(
      obj, codes.data(),
      static_cast<std::size_t>(charcodes.size())) != 0;
}

// ===========================================================================
// Phase B — annotation authoring completers.
// ===========================================================================

namespace {

// Init a transient FPDF_FORMHANDLE for FFL-requiring calls. PDFium's
// form-fill setters need an FPDF_FORMHANDLE even when the call only
// touches the annotation's own dictionary. The struct's `version`
// field must be set; the function-pointer callbacks may be NULL for
// the non-interactive batch path we exercise.
struct ScopedFormHandle {
  // ffi MUST be a member, not a local in the constructor: PDFium
  // stores the pointer internally and dereferences it on every
  // subsequent call (Init*, Set*, Exit). A constructor-local would
  // go out of scope before any of those callers ran, leaving a
  // dangling pointer that segfaults on Exit (free of a stale
  // FORMFILLINFO field). Keep it as a member so it lives at least
  // as long as `handle`.
  FPDF_FORMFILLINFO ffi{};
  FPDF_FORMHANDLE handle = nullptr;
  ScopedFormHandle(FPDF_DOCUMENT doc) {
    ffi.version = 2;
    handle = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  }
  ~ScopedFormHandle() {
    if (handle != nullptr) {
      FPDFDOC_ExitFormFillEnvironment(handle);
    }
  }
  ScopedFormHandle(const ScopedFormHandle&) = delete;
  ScopedFormHandle& operator=(const ScopedFormHandle&) = delete;
};

}  // namespace

// Append an ink stroke (Nx2 matrix of points) to an ink annotation.
// Returns the new stroke index, or -1 on failure.
// [[Rcpp::export(name = "cpp_annot_add_ink_stroke")]]
int cpp_annot_add_ink_stroke(SEXP annot_ptr, Rcpp::NumericMatrix points) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  if (points.ncol() != 2) {                   // # nocov start
    // R-side checkmate::assert_matrix(ncols = 2L) rejects this
    // already; defensive only.
    Rcpp::stop("`points` must have exactly 2 columns (x, y).");
  }                                            // # nocov end
  int n = points.nrow();
  std::vector<FS_POINTF> pts(n);
  for (int i = 0; i < n; ++i) {
    pts[i].x = static_cast<float>(points(i, 0));
    pts[i].y = static_cast<float>(points(i, 1));
  }
  return FPDFAnnot_AddInkStroke(annot, pts.data(),
                                  static_cast<std::size_t>(n));
}

// [[Rcpp::export(name = "cpp_annot_remove_ink_list")]]
bool cpp_annot_remove_ink_list(SEXP annot_ptr) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  return FPDFAnnot_RemoveInkList(annot) != 0;
}

// Append a page-object (already-detached, returned by
// FPDFPageObj_CreateNew*) into a stamp / freetext annotation.
// [[Rcpp::export(name = "cpp_annot_append_object")]]
bool cpp_annot_append_object(SEXP annot_ptr, SEXP obj_ptr) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  // After AppendObject, the annotation owns the page-object; clear
  // the R-side externalptr so subsequent calls error cleanly.
  bool ok = FPDFAnnot_AppendObject(annot, obj) != 0;
  if (ok) R_ClearExternalPtr(obj_ptr);
  return ok;
}

// [[Rcpp::export(name = "cpp_annot_remove_object")]]
bool cpp_annot_remove_object(SEXP annot_ptr, int index_zero) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  return FPDFAnnot_RemoveObject(annot, index_zero) != 0;
}

// [[Rcpp::export(name = "cpp_annot_update_object")]]
bool cpp_annot_update_object(SEXP annot_ptr, SEXP obj_ptr) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  return FPDFAnnot_UpdateObject(annot, obj) != 0;
}

// [[Rcpp::export(name = "cpp_annot_object_count")]]
int cpp_annot_object_count(SEXP annot_ptr) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  return FPDFAnnot_GetObjectCount(annot);
}

// Returns the page-object at the given index. The annotation owns it
// (no finalizer); the externalptr's prot slot pins the annot so the
// page-obj reference can't dangle.
// [[Rcpp::export(name = "cpp_annot_get_object")]]
SEXP cpp_annot_get_object(SEXP annot_ptr, int index_zero) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  FPDF_PAGEOBJECT obj = FPDFAnnot_GetObject(annot, index_zero);
  if (obj == nullptr) {
    Rcpp::stop("FPDFAnnot_GetObject returned NULL for index %d",
               index_zero);
  }
  return R_MakeExternalPtr(obj, R_NilValue, annot_ptr);
}

// [[Rcpp::export(name = "cpp_annot_set_uri")]]
bool cpp_annot_set_uri(SEXP annot_ptr, std::string uri) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  return FPDFAnnot_SetURI(annot, uri.c_str()) != 0;
}

// Appearance-mode encoding matches FPDF_ANNOT_APPEARANCEMODE_*:
// 0=NORMAL, 1=ROLLOVER, 2=DOWN.
// [[Rcpp::export(name = "cpp_annot_set_appearance")]]
bool cpp_annot_set_appearance(SEXP annot_ptr, int mode,
                                std::string value_utf8) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  if (value_utf8.empty()) {
    return FPDFAnnot_SetAP(
        annot, static_cast<FPDF_ANNOT_APPEARANCEMODE>(mode),
        nullptr) != 0;
  }
  std::vector<unsigned short> utf16 =
      pdfium_r::utf8_to_utf16le_nul(value_utf8);
  return FPDFAnnot_SetAP(
      annot, static_cast<FPDF_ANNOT_APPEARANCEMODE>(mode),
      reinterpret_cast<FPDF_WIDESTRING>(utf16.data())) != 0;
}

// Add a file-attachment to a fileattachment annotation. Returns an
// externalptr to FPDF_ATTACHMENT (no finalizer; the doc owns it).
// [[Rcpp::export(name = "cpp_annot_add_file_attachment")]]
SEXP cpp_annot_add_file_attachment(SEXP doc_ptr, SEXP annot_ptr,
                                      std::string name_utf8) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  std::vector<unsigned short> utf16 =
      pdfium_r::utf8_to_utf16le_nul(name_utf8);
  FPDF_ATTACHMENT att = FPDFAnnot_AddFileAttachment(
      annot, reinterpret_cast<FPDF_WIDESTRING>(utf16.data()));
  if (att == nullptr) {
    Rcpp::stop("FPDFAnnot_AddFileAttachment returned NULL — the "
               "annotation may not be of subtype fileattachment.");
  }
  (void)doc;  // pinned via prot
  return R_MakeExternalPtr(att, R_NilValue, doc_ptr);
}

// Get the line endpoints of a line annotation.
// [[Rcpp::export(name = "cpp_annot_line")]]
Rcpp::NumericVector cpp_annot_line(SEXP annot_ptr) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  FS_POINTF s{}, e{};
  if (!FPDFAnnot_GetLine(annot, &s, &e)) {
    return Rcpp::NumericVector::create(
      Rcpp::_["start_x"] = NA_REAL, Rcpp::_["start_y"] = NA_REAL,
      Rcpp::_["end_x"]   = NA_REAL, Rcpp::_["end_y"]   = NA_REAL);
  }
  return Rcpp::NumericVector::create(
    Rcpp::_["start_x"] = s.x, Rcpp::_["start_y"] = s.y,
    Rcpp::_["end_x"]   = e.x, Rcpp::_["end_y"]   = e.y);
}

// Link info for a link annotation. Returns a list mirroring the row
// shape of pdf_page_links() — action_type code + uri + filepath +
// dest_page_idx + dest_view + dest_x/y/zoom.
// [[Rcpp::export(name = "cpp_annot_link_info")]]
Rcpp::List cpp_annot_link_info(SEXP doc_ptr, SEXP annot_ptr) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  FPDF_LINK link = FPDFAnnot_GetLink(annot);
  if (link == nullptr) {
    return Rcpp::List::create(
      Rcpp::_["found"]       = false,
      Rcpp::_["action_code"] = 0,
      Rcpp::_["uri"]         = std::string(),
      Rcpp::_["filepath"]    = std::string(),
      Rcpp::_["dest_page"]   = NA_INTEGER,
      Rcpp::_["dest_view"]   = 0,
      Rcpp::_["dest_x"]      = NA_REAL,
      Rcpp::_["dest_y"]      = NA_REAL,
      Rcpp::_["dest_zoom"]   = NA_REAL);
  }
  FPDF_ACTION action = FPDFLink_GetAction(link);
  int code = 0, dest_idx = -1, dview = 0;
  double dx = NA_REAL, dy = NA_REAL, dzoom = NA_REAL;
  std::string uri_text, fp_text;
  pdfium_r::classify_action_with_dest(
      doc, action, FPDFLink_GetDest(doc, link),
      code, uri_text, fp_text, dest_idx, dview, dx, dy, dzoom);
  return Rcpp::List::create(
    Rcpp::_["found"]       = true,
    Rcpp::_["action_code"] = code,
    Rcpp::_["uri"]         = uri_text,
    Rcpp::_["filepath"]    = fp_text,
    Rcpp::_["dest_page"]   = dest_idx < 0 ? NA_INTEGER : dest_idx + 1,
    Rcpp::_["dest_view"]   = dview,
    Rcpp::_["dest_x"]      = dx,
    Rcpp::_["dest_y"]      = dy,
    Rcpp::_["dest_zoom"]   = dzoom);
}

// [[Rcpp::export(name = "cpp_annot_set_border")]]
bool cpp_annot_set_border(SEXP annot_ptr, double h_radius, double v_radius,
                            double width) {
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  return FPDFAnnot_SetBorder(annot,
                               static_cast<float>(h_radius),
                               static_cast<float>(v_radius),
                               static_cast<float>(width)) != 0;
}

// Doc-wide focusable-annotation-subtype setter. Takes an integer
// vector of subtype codes per the existing pdfium_annot_subtype_code()
// mapping.
// [[Rcpp::export(name = "cpp_annot_set_focusable_subtypes")]]
bool cpp_annot_set_focusable_subtypes(SEXP doc_ptr,
                                        Rcpp::IntegerVector codes) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  ScopedFormHandle env(doc);
  if (env.handle == nullptr) {  // # nocov start
    Rcpp::stop("FPDFDOC_InitFormFillEnvironment returned NULL.");
  }  // # nocov end
  std::vector<FPDF_ANNOTATION_SUBTYPE> subs(codes.size());
  for (R_xlen_t i = 0; i < codes.size(); ++i) {
    subs[i] = static_cast<FPDF_ANNOTATION_SUBTYPE>(codes[i]);
  }
  return FPDFAnnot_SetFocusableSubtypes(
      env.handle, subs.data(),
      static_cast<std::size_t>(codes.size())) != 0;
}

// [[Rcpp::export(name = "cpp_annot_set_font_color")]]
bool cpp_annot_set_font_color(SEXP doc_ptr, SEXP annot_ptr,
                                int r, int g, int b) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  ScopedFormHandle env(doc);
  if (env.handle == nullptr) {  // # nocov start
    Rcpp::stop("FPDFDOC_InitFormFillEnvironment returned NULL.");
  }  // # nocov end
  return FPDFAnnot_SetFontColor(
      env.handle, annot,
      static_cast<unsigned int>(r),
      static_cast<unsigned int>(g),
      static_cast<unsigned int>(b)) != 0;
}

// [[Rcpp::export(name = "cpp_annot_set_form_field_flags")]]
bool cpp_annot_set_form_field_flags(SEXP doc_ptr, SEXP annot_ptr,
                                      int flags) {
  FPDF_DOCUMENT doc = acomp_doc_from_ptr(doc_ptr);
  FPDF_ANNOTATION annot = acomp_annot_from_ptr(annot_ptr);
  ScopedFormHandle env(doc);
  if (env.handle == nullptr) {  // # nocov start
    Rcpp::stop("FPDFDOC_InitFormFillEnvironment returned NULL.");
  }  // # nocov end
  return FPDFAnnot_SetFormFieldFlags(env.handle, annot, flags) != 0;
}

// ===========================================================================
// Phase C — clip-path authoring.
// ===========================================================================

namespace {

inline FPDF_CLIPPATH acomp_clip_from_ptr(SEXP cp_ptr) {
  return static_cast<FPDF_CLIPPATH>(
      pdfium_r::validate_handle(cp_ptr, "Clip-path",
                                  /*require_prot_alive=*/false));
}

void clip_path_finalizer(SEXP cp_ptr) {
  if (TYPEOF(cp_ptr) != EXTPTRSXP) return;
  FPDF_CLIPPATH cp = static_cast<FPDF_CLIPPATH>(R_ExternalPtrAddr(cp_ptr));
  if (cp == nullptr) return;
  FPDF_DestroyClipPath(cp);
  R_ClearExternalPtr(cp_ptr);
}

}  // namespace

// Create a fresh clip path covering the given rectangle. Returns
// an externalptr with a finalizer that calls FPDF_DestroyClipPath.
// [[Rcpp::export(name = "cpp_clip_path_new")]]
SEXP cpp_clip_path_new(double left, double bottom,
                        double right, double top) {
  FPDF_CLIPPATH cp = FPDF_CreateClipPath(
      static_cast<float>(left), static_cast<float>(bottom),
      static_cast<float>(right), static_cast<float>(top));
  if (cp == nullptr) {  // # nocov start
    Rcpp::stop("FPDF_CreateClipPath returned NULL.");
  }  // # nocov end
  SEXP ext = PROTECT(R_MakeExternalPtr(cp, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(ext, clip_path_finalizer,
                         static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ext;
}

// Idempotent close — matches the doc/page/font close pattern.
// [[Rcpp::export(name = "cpp_clip_path_close")]]
void cpp_clip_path_close(SEXP cp_ptr) {
  if (TYPEOF(cp_ptr) != EXTPTRSXP) return;
  FPDF_CLIPPATH cp = static_cast<FPDF_CLIPPATH>(R_ExternalPtrAddr(cp_ptr));
  if (cp == nullptr) return;
  FPDF_DestroyClipPath(cp);
  R_ClearExternalPtr(cp_ptr);
}

// Insert the clip path as a page-level clip. Ownership transfers
// to the page (FPDFPage_InsertClipPath copies internally and the
// page takes ownership of the inserted entry). Clear the R-side
// externalptr so the finalizer is a no-op.
// [[Rcpp::export(name = "cpp_page_insert_clip_path")]]
void cpp_page_insert_clip_path(SEXP page_ptr, SEXP cp_ptr) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FPDF_CLIPPATH cp = acomp_clip_from_ptr(cp_ptr);
  FPDFPage_InsertClipPath(page, cp);
  // PDFium keeps an internal reference to the clip path data; the
  // wrapper's externalptr is no longer the unique owner. Clear it
  // to prevent a double-destroy via the finalizer.
  R_ClearExternalPtr(cp_ptr);
}

// Transform a page-object's clip path in-place. Returns void per
// PDFium's signature.
// [[Rcpp::export(name = "cpp_obj_transform_clip_path")]]
void cpp_obj_transform_clip_path(SEXP obj_ptr,
                                   double a, double b, double c,
                                   double d, double e, double f) {
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  FPDFPageObj_TransformClipPath(obj, a, b, c, d, e, f);
}

// Page-level transform-with-clip — applies the matrix to the entire
// page content stream and (optionally) clips to the given rect.
// PDFium takes a NULL clipRect when none is wanted.
// ===========================================================================
// Phase D — form-XObject / page-merge extras.
// ===========================================================================

namespace {

inline FPDF_XOBJECT acomp_xobj_from_ptr(SEXP xo_ptr) {
  return static_cast<FPDF_XOBJECT>(
      pdfium_r::validate_handle(xo_ptr, "XObject",
                                  /*require_prot_alive=*/false));
}

void xobject_finalizer(SEXP xo_ptr) {
  if (TYPEOF(xo_ptr) != EXTPTRSXP) return;
  FPDF_XOBJECT xo = static_cast<FPDF_XOBJECT>(R_ExternalPtrAddr(xo_ptr));
  if (xo == nullptr) return;
  FPDF_CloseXObject(xo);
  R_ClearExternalPtr(xo_ptr);
}

}  // namespace

// Create an FPDF_XOBJECT from a source-doc page.
// [[Rcpp::export(name = "cpp_xobject_from_page")]]
SEXP cpp_xobject_from_page(SEXP dest_doc_ptr, SEXP src_doc_ptr,
                             int src_page_index_zero) {
  FPDF_DOCUMENT dest = acomp_doc_from_ptr(dest_doc_ptr);
  FPDF_DOCUMENT src  = acomp_doc_from_ptr(src_doc_ptr);
  FPDF_XOBJECT xo = FPDF_NewXObjectFromPage(dest, src,
                                              src_page_index_zero);
  if (xo == nullptr) {
    Rcpp::stop("FPDF_NewXObjectFromPage returned NULL.");
  }
  // prot = dest_doc so the source-side doc isn't pinned (the XObject's
  // data has already been copied into dest_doc).
  SEXP ext = PROTECT(R_MakeExternalPtr(xo, R_NilValue, dest_doc_ptr));
  R_RegisterCFinalizerEx(ext, xobject_finalizer,
                         static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ext;
}

// Idempotent close.
// [[Rcpp::export(name = "cpp_xobject_close")]]
void cpp_xobject_close(SEXP xo_ptr) {
  if (TYPEOF(xo_ptr) != EXTPTRSXP) return;
  FPDF_XOBJECT xo = static_cast<FPDF_XOBJECT>(R_ExternalPtrAddr(xo_ptr));
  if (xo == nullptr) return;
  FPDF_CloseXObject(xo);
  R_ClearExternalPtr(xo_ptr);
}

// Create a form-xobject page-object from an FPDF_XOBJECT handle.
// The XObject can be reused across multiple form-obj instantiations
// (it stays alive until FPDF_CloseXObject is called). Returns a
// page-object externalptr; caller is responsible for inserting it
// into a page.
// [[Rcpp::export(name = "cpp_form_obj_from_xobject")]]
SEXP cpp_form_obj_from_xobject(SEXP xo_ptr) {
  FPDF_XOBJECT xo = acomp_xobj_from_ptr(xo_ptr);
  FPDF_PAGEOBJECT obj = FPDF_NewFormObjectFromXObject(xo);
  if (obj == nullptr) {  // # nocov start
    Rcpp::stop("FPDF_NewFormObjectFromXObject returned NULL.");
  }  // # nocov end
  // The page-object is detached until inserted into a page. prot =
  // the xobject pointer pins it (so the XObject outlives any
  // page-objects derived from it).
  return R_MakeExternalPtr(obj, R_NilValue, xo_ptr);
}

// Insert a detached page-object (e.g. returned by
// cpp_form_obj_from_xobject) into a page. Wraps
// FPDFPage_InsertObject for the standalone-insertion path the
// existing creators do internally.
// [[Rcpp::export(name = "cpp_page_insert_object")]]
void cpp_page_insert_object(SEXP page_ptr, SEXP obj_ptr) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  FPDF_PAGEOBJECT obj = acomp_obj_from_ptr(obj_ptr);
  FPDFPage_InsertObject(page, obj);
}

// Remove a child page-object from a form-xobject.
// [[Rcpp::export(name = "cpp_form_obj_remove_child")]]
bool cpp_form_obj_remove_child(SEXP form_obj_ptr, SEXP child_ptr) {
  FPDF_PAGEOBJECT form_obj = acomp_obj_from_ptr(form_obj_ptr);
  FPDF_PAGEOBJECT child    = acomp_obj_from_ptr(child_ptr);
  return FPDFFormObj_RemoveObject(form_obj, child) != 0;
}

// ===========================================================================
// Phase E — image-bitmap embedding (FPDF_BITMAP lifecycle).
// ===========================================================================

namespace {

inline FPDF_BITMAP acomp_bitmap_from_ptr(SEXP bm_ptr) {
  return static_cast<FPDF_BITMAP>(
      pdfium_r::validate_handle(bm_ptr, "Bitmap",
                                  /*require_prot_alive=*/false));
}

void bitmap_finalizer(SEXP bm_ptr) {
  if (TYPEOF(bm_ptr) != EXTPTRSXP) return;
  FPDF_BITMAP bm = static_cast<FPDF_BITMAP>(R_ExternalPtrAddr(bm_ptr));
  if (bm == nullptr) return;
  FPDFBitmap_Destroy(bm);
  R_ClearExternalPtr(bm_ptr);
}

}  // namespace

// [[Rcpp::export(name = "cpp_bitmap_new")]]
SEXP cpp_bitmap_new(int width, int height, bool alpha) {
  FPDF_BITMAP bm = FPDFBitmap_Create(width, height, alpha ? 1 : 0);
  if (bm == nullptr) {  // # nocov start
    Rcpp::stop("FPDFBitmap_Create returned NULL (likely out of "
               "memory or invalid dimensions).");
  }  // # nocov end
  SEXP ext = PROTECT(R_MakeExternalPtr(bm, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(ext, bitmap_finalizer,
                         static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ext;
}

// [[Rcpp::export(name = "cpp_bitmap_close")]]
void cpp_bitmap_close(SEXP bm_ptr) {
  if (TYPEOF(bm_ptr) != EXTPTRSXP) return;
  FPDF_BITMAP bm = static_cast<FPDF_BITMAP>(R_ExternalPtrAddr(bm_ptr));
  if (bm == nullptr) return;
  FPDFBitmap_Destroy(bm);
  R_ClearExternalPtr(bm_ptr);
}

// [[Rcpp::export(name = "cpp_bitmap_info")]]
Rcpp::List cpp_bitmap_info(SEXP bm_ptr) {
  FPDF_BITMAP bm = acomp_bitmap_from_ptr(bm_ptr);
  return Rcpp::List::create(
    Rcpp::_["width"]  = FPDFBitmap_GetWidth(bm),
    Rcpp::_["height"] = FPDFBitmap_GetHeight(bm),
    Rcpp::_["stride"] = FPDFBitmap_GetStride(bm),
    Rcpp::_["format"] = FPDFBitmap_GetFormat(bm));
}

// Fill a rectangle in the bitmap. Color is encoded as 0xAARRGGBB
// passed as a double (since R has no native unsigned 32-bit type).
// [[Rcpp::export(name = "cpp_bitmap_fill_rect")]]
bool cpp_bitmap_fill_rect(SEXP bm_ptr, int left, int top,
                            int width, int height, double color) {
  FPDF_BITMAP bm = acomp_bitmap_from_ptr(bm_ptr);
  return FPDFBitmap_FillRect(
      bm, left, top, width, height,
      static_cast<FPDF_DWORD>(static_cast<std::uint32_t>(color))) != 0;
}

// Read the bitmap's pixel bytes into a raw vector. Total length is
// stride * height. The R side is responsible for unpacking per the
// reported format.
// [[Rcpp::export(name = "cpp_bitmap_buffer")]]
Rcpp::RawVector cpp_bitmap_buffer(SEXP bm_ptr) {
  FPDF_BITMAP bm = acomp_bitmap_from_ptr(bm_ptr);
  int height = FPDFBitmap_GetHeight(bm);
  int stride = FPDFBitmap_GetStride(bm);
  std::size_t n = static_cast<std::size_t>(height) *
                  static_cast<std::size_t>(stride);
  const unsigned char* p =
      static_cast<const unsigned char*>(FPDFBitmap_GetBuffer(bm));
  Rcpp::RawVector out(n);
  std::copy_n(p, n, out.begin());
  return out;
}

// Set the bitmap's pixel bytes from a raw vector. The vector's
// length must equal stride * height (else the call errors).
// [[Rcpp::export(name = "cpp_bitmap_set_buffer")]]
bool cpp_bitmap_set_buffer(SEXP bm_ptr, Rcpp::RawVector data) {
  FPDF_BITMAP bm = acomp_bitmap_from_ptr(bm_ptr);
  int height = FPDFBitmap_GetHeight(bm);
  int stride = FPDFBitmap_GetStride(bm);
  std::size_t expected = static_cast<std::size_t>(height) *
                         static_cast<std::size_t>(stride);
  if (static_cast<std::size_t>(data.size()) != expected) {
    Rcpp::stop("Buffer size %d does not match stride * height (%d).",
               static_cast<int>(data.size()),
               static_cast<int>(expected));
  }
  unsigned char* p =
      static_cast<unsigned char*>(FPDFBitmap_GetBuffer(bm));
  std::copy_n(&data[0], expected, p);
  return true;
}

// Set the bitmap on an image page-object. The pages array tells
// PDFium which pages already reference this image so it can
// invalidate their cached renderings; we pass an empty array
// because the calling pattern is "set bitmap before inserting on
// any page".
// [[Rcpp::export(name = "cpp_image_set_bitmap")]]
bool cpp_image_set_bitmap(SEXP image_obj_ptr, SEXP bitmap_ptr) {
  FPDF_PAGEOBJECT image_obj = acomp_obj_from_ptr(image_obj_ptr);
  FPDF_BITMAP bm = acomp_bitmap_from_ptr(bitmap_ptr);
  // Empty pages array — caller is responsible for inserting on a
  // page afterward via FPDFPage_InsertObject. PDFium documents
  // accept count = 0 + pages = nullptr.
  return FPDFImageObj_SetBitmap(nullptr, 0, image_obj, bm) != 0;
}

// ===========================================================================
// Phase G — system font integration (inspectable surface only).
// ===========================================================================
//
// PDFium's font-substitution system has three layers:
//   1. A static "charset → TTF name" map shipped with the build,
//      accessible via FPDF_GetDefaultTTFMap[Count|Entry]. The map
//      tells PDFium which TTF to substitute when a doc references
//      a font by charset code only.
//   2. The platform's default sys-font-info provider
//      (FPDF_GetDefaultSystemFontInfo) — a callback table that
//      enumerates installed fonts and maps requests by name to a
//      handle PDFium can read bytes from.
//   3. A custom provider (FPDF_SetSystemFontInfo) — the embedder
//      installs its own callback table. R-side callbacks here would
//      require complex marshalling and are deferred to v0.2.0+.
//
// What's wrapped:
//   * cpp_default_ttf_map_size / cpp_default_ttf_map_entry — readers
//     for the static map.
//   * cpp_install_default_sysfont_info — calls
//     FPDF_SetSystemFontInfo(FPDF_GetDefaultSystemFontInfo()) so
//     PDFium uses the platform's default fallback provider when
//     resolving missing glyphs.
//
// What's skipped (deferred):
//   * FPDF_AddInstalledFont — only called from within an EnumFonts
//     callback, requires R-side callback machinery.
//   * FPDF_FreeDefaultSystemFontInfo — internal cleanup of the
//     default provider; managed by the install_default call.
//   * Custom FPDF_SetSystemFontInfo with R callbacks — needs full
//     FPDF_SYSFONTINFO marshalling.

// [[Rcpp::export(name = "cpp_default_ttf_map_size")]]
int cpp_default_ttf_map_size() {
  return static_cast<int>(FPDF_GetDefaultTTFMapCount());
}

// Returns charset code + TTF name for the entry at `index_zero`.
// [[Rcpp::export(name = "cpp_default_ttf_map_entry")]]
Rcpp::List cpp_default_ttf_map_entry(int index_zero) {
  const FPDF_CharsetFontMap* entry =
      FPDF_GetDefaultTTFMapEntry(static_cast<size_t>(index_zero));
  if (entry == nullptr) {
    Rcpp::stop("FPDF_GetDefaultTTFMapEntry returned NULL "
               "(index %d out of bounds).", index_zero);
  }
  std::string name(entry->fontname != nullptr ? entry->fontname : "");
  return Rcpp::List::create(
    Rcpp::_["charset"] = entry->charset,
    Rcpp::_["fontname"] = name);
}

// Install PDFium's platform-default system font info provider.
// One-shot; subsequent calls reinstall the same provider.
// [[Rcpp::export(name = "cpp_install_default_sysfont_info")]]
bool cpp_install_default_sysfont_info() {
  FPDF_SYSFONTINFO* info = FPDF_GetDefaultSystemFontInfo();
  if (info == nullptr) {  // # nocov start — only returns NULL on PDFium
    return false;         // builds compiled without system-font support;
  }                       // chromium/7202 (our bundled binary) always
                          // returns a non-NULL provider.
  // # nocov end
  FPDF_SetSystemFontInfo(info);
  // Note: we deliberately don't call FPDF_FreeDefaultSystemFontInfo
  // here — PDFium retains the pointer for the lifetime of the
  // library. The provider lives until package unload.
  return true;
}

// String-range import: "1-3,5,7-10" syntax for page ranges.
// [[Rcpp::export(name = "cpp_doc_import_pages_string")]]
bool cpp_doc_import_pages_string(SEXP dest_ptr, SEXP src_ptr,
                                   std::string range, int dest_index_zero) {
  FPDF_DOCUMENT dest = acomp_doc_from_ptr(dest_ptr);
  FPDF_DOCUMENT src  = acomp_doc_from_ptr(src_ptr);
  const char* range_arg = range.empty() ? nullptr : range.c_str();
  return FPDF_ImportPages(dest, src, range_arg, dest_index_zero) != 0;
}

// [[Rcpp::export(name = "cpp_page_transform_with_clip")]]
bool cpp_page_transform_with_clip(SEXP page_ptr,
                                    Rcpp::NumericVector matrix,
                                    Rcpp::NumericVector clip_rect) {
  FPDF_PAGE page = acomp_page_from_ptr(page_ptr);
  if (matrix.size() != 6) {  // # nocov start — R wrapper validates
    Rcpp::stop("`matrix` must be a length-6 numeric vector "
               "(a, b, c, d, e, f).");
  }  // # nocov end
  FS_MATRIX m;
  m.a = static_cast<float>(matrix[0]); m.b = static_cast<float>(matrix[1]);
  m.c = static_cast<float>(matrix[2]); m.d = static_cast<float>(matrix[3]);
  m.e = static_cast<float>(matrix[4]); m.f = static_cast<float>(matrix[5]);
  const FS_RECTF* rect_arg = nullptr;
  FS_RECTF rect;
  if (clip_rect.size() == 4) {
    rect.left   = static_cast<float>(clip_rect[0]);
    rect.bottom = static_cast<float>(clip_rect[1]);
    rect.right  = static_cast<float>(clip_rect[2]);
    rect.top    = static_cast<float>(clip_rect[3]);
    rect_arg = &rect;
  } else if (clip_rect.size() != 0) {  // # nocov start — R wrapper validates
    Rcpp::stop("`clip_rect` must be NULL or a length-4 numeric "
               "vector (left, bottom, right, top).");
  }  // # nocov end
  return FPDFPage_TransFormWithClip(page, &m, rect_arg) != 0;
}
