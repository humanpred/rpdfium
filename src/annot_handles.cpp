// pdfium R package — per-annotation handle shims.
//
// Companion to src/annotations.cpp's bulk reader. Where the bulk
// reader returns one big table for all annotations on a page, this
// file returns ONE annotation handle at a time. The handle is an R
// externalptr with a finalizer that calls FPDFPage_CloseAnnot, so
// R's GC reclaims annotation memory deterministically when the
// `pdfium_annot` is no longer reachable.
//
// Per-attribute getters live here too. Each is a single PDFium
// call; the R-side `pdf_annot_*` functions are thin wrappers.
// Inputs are always the bare externalptr; the R layer validates
// shape via checkmate before calling.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_attachment.h"
#include "fpdf_formfill.h"
#include "utf16.h"

namespace {

FPDF_ANNOTATION annot_from_ptr(SEXP annot_ptr) {
  if (TYPEOF(annot_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the annotation.");
  }
  FPDF_ANNOTATION annot =
      static_cast<FPDF_ANNOTATION>(R_ExternalPtrAddr(annot_ptr));
  if (annot == nullptr) {
    Rcpp::stop("Annotation handle is NULL (closed?).");
  }
  return annot;
}

FPDF_PAGE page_from_ptr_local(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

void finalize_annot(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) return;
  FPDF_ANNOTATION a =
      static_cast<FPDF_ANNOTATION>(R_ExternalPtrAddr(ptr));
  if (a != nullptr) {
    FPDFPage_CloseAnnot(a);
    R_ClearExternalPtr(ptr);
  }
}

std::string read_annot_string_local(FPDF_ANNOTATION annot, const char* key) {
  unsigned long needed = FPDFAnnot_GetStringValue(annot, key, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDFAnnot_GetStringValue(annot, key,
                           reinterpret_cast<FPDF_WCHAR*>(buf.data()),
                           needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

}  // namespace

// [[Rcpp::export(name = "cpp_annot_get")]]
SEXP cpp_annot_get(SEXP page_ptr, int index_zero_based) {
  FPDF_PAGE page = page_from_ptr_local(page_ptr);
  FPDF_ANNOTATION a = FPDFPage_GetAnnot(page, index_zero_based);
  if (a == nullptr) {
    Rcpp::stop("FPDFPage_GetAnnot(%d) returned NULL.",
               index_zero_based);
  }
  // Pin the parent page in the externalptr's `prot` slot so the
  // page can't be GC'd before this annot handle. Matches the
  // pattern used by pdfium_obj.
  SEXP ptr = PROTECT(R_MakeExternalPtr(a, R_NilValue, page_ptr));
  R_RegisterCFinalizerEx(ptr, finalize_annot,
                         static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return ptr;
}

// [[Rcpp::export(name = "cpp_annot_subtype_code")]]
int cpp_annot_subtype_code(SEXP annot_ptr) {
  return static_cast<int>(FPDFAnnot_GetSubtype(annot_from_ptr(annot_ptr)));
}

// [[Rcpp::export(name = "cpp_annot_flags")]]
int cpp_annot_flags(SEXP annot_ptr) {
  return FPDFAnnot_GetFlags(annot_from_ptr(annot_ptr));
}

// [[Rcpp::export(name = "cpp_annot_bounds")]]
Rcpp::NumericVector cpp_annot_bounds(SEXP annot_ptr) {
  FS_RECTF r;
  Rcpp::NumericVector out =
      Rcpp::NumericVector::create(NA_REAL, NA_REAL, NA_REAL, NA_REAL);
  out.attr("names") = Rcpp::CharacterVector::create(
      "bounds_left", "bounds_bottom", "bounds_right", "bounds_top");
  if (FPDFAnnot_GetRect(annot_from_ptr(annot_ptr), &r)) {
    out[0] = r.left;
    out[1] = r.bottom;
    out[2] = r.right;
    out[3] = r.top;
  }
  return out;
}

// [[Rcpp::export(name = "cpp_annot_string_value")]]
std::string cpp_annot_string_value(SEXP annot_ptr, std::string key) {
  return read_annot_string_local(annot_from_ptr(annot_ptr), key.c_str());
}

// [[Rcpp::export(name = "cpp_annot_color")]]
Rcpp::NumericVector cpp_annot_color(SEXP annot_ptr,
                                    bool interior) {
  unsigned int r = 0, g = 0, b = 0, a = 255;
  Rcpp::NumericVector out =
      Rcpp::NumericVector::create(NA_REAL, NA_REAL, NA_REAL, NA_REAL);
  out.attr("names") = Rcpp::CharacterVector::create(
      "red", "green", "blue", "alpha");
  FPDFANNOT_COLORTYPE ct = interior ? FPDFANNOT_COLORTYPE_InteriorColor
                                    : FPDFANNOT_COLORTYPE_Color;
  if (FPDFAnnot_GetColor(annot_from_ptr(annot_ptr), ct,
                         &r, &g, &b, &a)) {
    out[0] = r / 255.0;
    out[1] = g / 255.0;
    out[2] = b / 255.0;
    out[3] = a / 255.0;
  }
  return out;
}

// [[Rcpp::export(name = "cpp_annot_border")]]
double cpp_annot_border(SEXP annot_ptr) {
  float h = 0.f, v = 0.f, w = 0.f;
  if (!FPDFAnnot_GetBorder(annot_from_ptr(annot_ptr), &h, &v, &w)) {
    return NA_REAL;
  }
  return w;
}

// [[Rcpp::export(name = "cpp_annot_font_size")]]
double cpp_annot_font_size(SEXP annot_ptr, SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) return NA_REAL;
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) return NA_REAL;
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) return NA_REAL;
  float sz = 0.f;
  bool ok = FPDFAnnot_GetFontSize(form, annot_from_ptr(annot_ptr), &sz);
  FPDFDOC_ExitFormFillEnvironment(form);
  return ok ? sz : NA_REAL;
}

// [[Rcpp::export(name = "cpp_annot_font_color")]]
Rcpp::NumericVector cpp_annot_font_color(SEXP annot_ptr, SEXP doc_ptr) {
  Rcpp::NumericVector out =
      Rcpp::NumericVector::create(NA_REAL, NA_REAL, NA_REAL);
  out.attr("names") =
      Rcpp::CharacterVector::create("red", "green", "blue");
  if (TYPEOF(doc_ptr) != EXTPTRSXP) return out;
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) return out;
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) return out;
  unsigned int r = 0, g = 0, b = 0;
  if (FPDFAnnot_GetFontColor(form, annot_from_ptr(annot_ptr),
                             &r, &g, &b)) {
    out[0] = r / 255.0;
    out[1] = g / 255.0;
    out[2] = b / 255.0;
  }
  FPDFDOC_ExitFormFillEnvironment(form);
  return out;
}

// [[Rcpp::export(name = "cpp_annot_has_attachment_points")]]
bool cpp_annot_has_attachment_points(SEXP annot_ptr) {
  return FPDFAnnot_HasAttachmentPoints(annot_from_ptr(annot_ptr));
}

// [[Rcpp::export(name = "cpp_annot_quad_points_handle")]]
SEXP cpp_annot_quad_points_handle(SEXP annot_ptr) {
  FPDF_ANNOTATION annot = annot_from_ptr(annot_ptr);
  if (!FPDFAnnot_HasAttachmentPoints(annot)) return R_NilValue;
  size_t n = FPDFAnnot_CountAttachmentPoints(annot);
  if (n == 0) return R_NilValue;
  Rcpp::NumericMatrix m(static_cast<int>(n), 8);
  for (size_t i = 0; i < n; ++i) {
    FS_QUADPOINTSF q;
    if (!FPDFAnnot_GetAttachmentPoints(annot, i, &q)) {
      for (int k = 0; k < 8; ++k) {
        m(static_cast<int>(i), k) = NA_REAL;
      }
      continue;
    }
    m(static_cast<int>(i), 0) = q.x1;
    m(static_cast<int>(i), 1) = q.y1;
    m(static_cast<int>(i), 2) = q.x2;
    m(static_cast<int>(i), 3) = q.y2;
    m(static_cast<int>(i), 4) = q.x3;
    m(static_cast<int>(i), 5) = q.y3;
    m(static_cast<int>(i), 6) = q.x4;
    m(static_cast<int>(i), 7) = q.y4;
  }
  Rcpp::CharacterVector cn = {"x1", "y1", "x2", "y2",
                                "x3", "y3", "x4", "y4"};
  Rcpp::colnames(m) = cn;
  return m;
}

// [[Rcpp::export(name = "cpp_annot_vertices_handle")]]
SEXP cpp_annot_vertices_handle(SEXP annot_ptr) {
  FPDF_ANNOTATION annot = annot_from_ptr(annot_ptr);
  unsigned long n = FPDFAnnot_GetVertices(annot, nullptr, 0);
  if (n == 0) return R_NilValue;
  std::vector<FS_POINTF> buf(n);
  if (FPDFAnnot_GetVertices(annot, buf.data(), n) != n) {
    return R_NilValue;
  }
  Rcpp::NumericMatrix m(static_cast<int>(n), 2);
  for (unsigned long i = 0; i < n; ++i) {
    m(static_cast<int>(i), 0) = buf[i].x;
    m(static_cast<int>(i), 1) = buf[i].y;
  }
  Rcpp::CharacterVector cn = {"x", "y"};
  Rcpp::colnames(m) = cn;
  return m;
}

// [[Rcpp::export(name = "cpp_annot_ink_paths_handle")]]
SEXP cpp_annot_ink_paths_handle(SEXP annot_ptr) {
  FPDF_ANNOTATION annot = annot_from_ptr(annot_ptr);
  unsigned long n_paths = FPDFAnnot_GetInkListCount(annot);
  if (n_paths == 0) return R_NilValue;
  Rcpp::List out(n_paths);
  for (unsigned long p = 0; p < n_paths; ++p) {
    unsigned long n = FPDFAnnot_GetInkListPath(annot, p, nullptr, 0);
    if (n == 0) {
      out[p] = Rcpp::NumericMatrix(0, 2);
      continue;
    }
    std::vector<FS_POINTF> buf(n);
    FPDFAnnot_GetInkListPath(annot, p, buf.data(), n);
    Rcpp::NumericMatrix m(static_cast<int>(n), 2);
    for (unsigned long i = 0; i < n; ++i) {
      m(static_cast<int>(i), 0) = buf[i].x;
      m(static_cast<int>(i), 1) = buf[i].y;
    }
    Rcpp::CharacterVector cn = {"x", "y"};
    Rcpp::colnames(m) = cn;
    out[p] = m;
  }
  return out;
}

// Resolve a linked annotation (Popup, IRT) and return BOTH:
//   * a fresh externalptr with a finalizer (FPDFPage_CloseAnnot),
//   * the 1-based index of that annot on the page.
// `key` is the linked-annot dict name (`"Popup"` or `"IRT"`).
// `page_ptr` is needed because resolving the index requires walking
// the page's annots to compare pointers (PDFium has no direct
// "index of an annotation" API).
// [[Rcpp::export(name = "cpp_annot_linked_handle")]]
Rcpp::List cpp_annot_linked_handle(SEXP annot_ptr, SEXP page_ptr,
                                    std::string key) {
  FPDF_ANNOTATION annot = annot_from_ptr(annot_ptr);
  FPDF_PAGE page = page_from_ptr_local(page_ptr);
  FPDF_ANNOTATION linked =
      FPDFAnnot_GetLinkedAnnot(annot, key.c_str());
  if (linked == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["found"]  = false,
        Rcpp::_["handle"] = R_NilValue,
        Rcpp::_["index"]  = NA_INTEGER);
  }
  // Walk page annots to find the index — PDFium has no index-of API.
  int found_idx = -1;
  int n = FPDFPage_GetAnnotCount(page);
  for (int i = 0; i < n; ++i) {
    FPDF_ANNOTATION cand = FPDFPage_GetAnnot(page, i);
    if (cand == nullptr) continue;
    bool match = (cand == linked);
    FPDFPage_CloseAnnot(cand);
    if (match) {
      found_idx = i + 1;
      break;
    }
  }
  // The walk above yielded a fresh handle. We close it and re-mint
  // one via the same FPDFPage_GetAnnot path so the externalptr's
  // ownership story matches cpp_annot_get().
  FPDFPage_CloseAnnot(linked);
  if (found_idx < 0) {
    return Rcpp::List::create(
        Rcpp::_["found"]  = true,
        Rcpp::_["handle"] = R_NilValue,
        Rcpp::_["index"]  = NA_INTEGER);
  }
  FPDF_ANNOTATION fresh = FPDFPage_GetAnnot(page, found_idx - 1);
  if (fresh == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["found"]  = true,
        Rcpp::_["handle"] = R_NilValue,
        Rcpp::_["index"]  = found_idx);
  }
  SEXP ptr = PROTECT(R_MakeExternalPtr(fresh, R_NilValue, page_ptr));
  R_RegisterCFinalizerEx(ptr, finalize_annot,
                          static_cast<Rboolean>(TRUE));
  UNPROTECT(1);
  return Rcpp::List::create(
      Rcpp::_["found"]  = true,
      Rcpp::_["handle"] = ptr,
      Rcpp::_["index"]  = found_idx);
}

// File-attachment annotation payload: returns the attached file's
// name string. The doc owns the FPDF_ATTACHMENT (it lives in the
// doc's /EmbeddedFiles), so the R wrapper can hand the same name
// to the doc-level attachment lookup if needed.
// [[Rcpp::export(name = "cpp_annot_file_attachment_name_handle")]]
std::string cpp_annot_file_attachment_name_handle(SEXP annot_ptr) {
  FPDF_ANNOTATION annot = annot_from_ptr(annot_ptr);
  if (FPDFAnnot_GetSubtype(annot) != FPDF_ANNOT_FILEATTACHMENT) {
    return std::string();
  }
  FPDF_ATTACHMENT att = FPDFAnnot_GetFileAttachment(annot);
  if (att == nullptr) return std::string();
  unsigned long needed = FPDFAttachment_GetName(att, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDFAttachment_GetName(att, reinterpret_cast<FPDF_WCHAR*>(buf.data()),
                          needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}
