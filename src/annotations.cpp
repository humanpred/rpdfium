// pdfium R package — annotation enumeration on a page.
//
// PDFium models annotations as FPDF_ANNOTATION handles per page
// with a 29-entry subtype enum (FPDF_ANNOT_TEXT through
// FPDF_ANNOT_REDACT) plus FPDF_ANNOT_UNKNOWN. Each annotation
// carries a rectangle in PDF user space, a 32-bit flags bitmask
// (visible/invisible/print/locked/...), and an unbounded
// key/value dictionary; this wrapper exposes the structural
// scalars plus the two free-text string entries most annotation
// kinds carry: /Contents (the annotation body text) and /T
// (the title / author).
//
// Lifetime: each FPDF_ANNOTATION must be closed via
// FPDFPage_CloseAnnot when the caller is done with it. We open
// and close it inside the C++ wrapper for each row, so no
// PDFium-owned annotation handle leaves the R side.

#include <Rcpp.h>
#include <cstdint>
#include <vector>
#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_attachment.h"
#include "fpdf_formfill.h"
#include "utf16.h"

namespace {

FPDF_PAGE page_from_ptr(SEXP page_ptr) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  return page;
}

std::string read_annot_string(FPDF_ANNOTATION annot, const char* key) {
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

// [[Rcpp::export(name = "cpp_annot_count")]]
int cpp_annot_count(SEXP page_ptr) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  int n = FPDFPage_GetAnnotCount(page);
  if (n < 0) {
    Rcpp::stop("FPDFPage_GetAnnotCount returned %d.", n);
  }
  return n;
}

// Helper: pull the four components of a single annotation color
// (FPDFANNOT_COLORTYPE_Color or _InteriorColor) into 0..1 doubles,
// or fill all four slots with NA_REAL when the annotation has no
// color set for that role.
//
// PDFium's FPDFAnnot_GetColor falls back to the appearance stream's
// color when /C (or /IC) is absent from the annotation dictionary,
// which makes "color was not specified" indistinguishable from
// "the appearance stream draws in black" at the API surface. We
// gate on FPDFAnnot_HasKey first so callers get NA when the PDF
// genuinely didn't set the color.
void read_annot_color(FPDF_ANNOTATION annot,
                      FPDFANNOT_COLORTYPE which,
                      double& r, double& g, double& b, double& a) {
  const char* key = (which == FPDFANNOT_COLORTYPE_InteriorColor)
                       ? "IC" : "C";
  if (!FPDFAnnot_HasKey(annot, key)) {
    r = g = b = a = NA_REAL;
    return;
  }
  unsigned int ur = 0, ug = 0, ub = 0, ua = 0;
  if (FPDFAnnot_GetColor(annot, which, &ur, &ug, &ub, &ua)) {
    r = ur / 255.0;
    g = ug / 255.0;
    b = ub / 255.0;
    a = ua / 255.0;
  } else {
    r = g = b = a = NA_REAL;
  }
}

// Helper: read all sets of attachment points (quadpoints) from an
// annotation. Returns an N x 8 numeric matrix with columns
// x1, y1, x2, y2, x3, y3, x4, y4 (one row per quad set), or
// R_NilValue when the annotation has no quadpoints.
SEXP read_annot_quad_points(FPDF_ANNOTATION annot) {
  if (!FPDFAnnot_HasAttachmentPoints(annot)) return R_NilValue;
  size_t n = FPDFAnnot_CountAttachmentPoints(annot);
  if (n == 0) return R_NilValue;
  Rcpp::NumericMatrix m(static_cast<int>(n), 8);
  for (size_t i = 0; i < n; ++i) {
    FS_QUADPOINTSF q;
    if (!FPDFAnnot_GetAttachmentPoints(annot, i, &q)) {
      for (int k = 0; k < 8; ++k) m(static_cast<int>(i), k) = NA_REAL;
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

// Helper: read the /Vertices array of a line / polygon / polyline
// annotation. Returns an N x 2 numeric matrix (columns x, y), or
// R_NilValue when the annotation type doesn't carry vertices.
SEXP read_annot_vertices(FPDF_ANNOTATION annot) {
  unsigned long n = FPDFAnnot_GetVertices(annot, nullptr, 0);
  if (n == 0) return R_NilValue;
  std::vector<FS_POINTF> buf(n);
  if (FPDFAnnot_GetVertices(annot, buf.data(), n) != n) return R_NilValue;
  Rcpp::NumericMatrix m(static_cast<int>(n), 2);
  for (unsigned long i = 0; i < n; ++i) {
    m(static_cast<int>(i), 0) = buf[i].x;
    m(static_cast<int>(i), 1) = buf[i].y;
  }
  Rcpp::CharacterVector cn = {"x", "y"};
  Rcpp::colnames(m) = cn;
  return m;
}

// Helper: read the ink-list paths of an ink annotation. Returns a
// list of N x 2 numeric matrices, one per stroke, or R_NilValue
// when the annotation is not of type ink.
SEXP read_annot_ink_paths(FPDF_ANNOTATION annot) {
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

// Helper: read the name string from an FPDF_ATTACHMENT handle.
// Returns "" when absent.
std::string read_attachment_name(FPDF_ATTACHMENT attachment) {
  if (attachment == nullptr) return std::string();
  unsigned long needed = FPDFAttachment_GetName(attachment, nullptr, 0);
  if (needed <= 2) return std::string();
  std::vector<unsigned short> buf(needed / 2);
  FPDFAttachment_GetName(attachment, buf.data(), needed);
  size_t wchars = (needed >= 2 ? needed / 2 - 1 : needed / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// Locate the same-page annotation_index (1-based) of `target` by
// scanning the page's annotation table. Returns -1 if `target` is
// nullptr or not found.
int find_annot_index(FPDF_PAGE page, FPDF_ANNOTATION target) {
  if (target == nullptr) return -1;
  int n = FPDFPage_GetAnnotCount(page);
  for (int i = 0; i < n; ++i) {
    FPDF_ANNOTATION a = FPDFPage_GetAnnot(page, i);
    if (a == nullptr) continue;
    bool match = (a == target);
    if (!match) {
      // PDFium hands out fresh wrapper handles per call, so equality
      // of FPDF_ANNOTATION pointers is unreliable. Match by the
      // underlying annot-dict pointer via the only stable property
      // available: each annot has a unique /Rect. Compare rects.
      FS_RECTF r1, r2;
      if (FPDFAnnot_GetRect(a, &r1) &&
          FPDFAnnot_GetRect(target, &r2)) {
        match = (r1.left == r2.left && r1.right == r2.right &&
                 r1.top == r2.top && r1.bottom == r2.bottom &&
                 FPDFAnnot_GetSubtype(a) == FPDFAnnot_GetSubtype(target));
      }
    }
    FPDFPage_CloseAnnot(a);
    if (match) return i + 1;
  }
  return -1;
}

// [[Rcpp::export(name = "cpp_annots_list")]]
Rcpp::List cpp_annots_list(SEXP doc_ptr, SEXP page_ptr) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  int n = FPDFPage_GetAnnotCount(page);
  if (n < 0) n = 0;

  // Form-fill env is needed for FPDFAnnot_GetFontColor /
  // GetFontSize; both call into the form's interactive form model.
  // We use the same minimal initialisation as src/form_fields.cpp.
  // PDFium has no FPDF_GetPageDocument accessor, so the R wrapper
  // hands us the owning doc explicitly via the page's parent ref.
  FPDF_DOCUMENT owning_doc = nullptr;
  if (TYPEOF(doc_ptr) == EXTPTRSXP) {
    owning_doc = static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  }
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = (owning_doc != nullptr)
      ? FPDFDOC_InitFormFillEnvironment(owning_doc, &ffi)
      : nullptr;

  Rcpp::IntegerVector   subtype_code(n);
  Rcpp::IntegerVector   flags(n);
  Rcpp::NumericVector   left(n);
  Rcpp::NumericVector   bottom(n);
  Rcpp::NumericVector   right(n);
  Rcpp::NumericVector   top(n);
  Rcpp::CharacterVector contents(n);
  Rcpp::CharacterVector title(n);
  Rcpp::CharacterVector subject(n);
  Rcpp::NumericVector   color_r(n), color_g(n), color_b(n), color_a(n);
  Rcpp::NumericVector   interior_r(n), interior_g(n), interior_b(n),
                         interior_a(n);
  Rcpp::NumericVector   border_width(n);
  Rcpp::List            quad_points(n);
  Rcpp::List            vertices(n);
  Rcpp::List            ink_paths(n);
  Rcpp::NumericVector   font_color_r(n), font_color_g(n), font_color_b(n);
  Rcpp::NumericVector   font_size(n);
  Rcpp::IntegerVector   popup_index(n);
  Rcpp::IntegerVector   irt_index(n);
  Rcpp::CharacterVector file_attachment_name(n);

  for (int i = 0; i < n; ++i) {
    FPDF_ANNOTATION annot = FPDFPage_GetAnnot(page, i);
    if (annot == nullptr) {
      subtype_code[i] = NA_INTEGER;
      flags[i]        = NA_INTEGER;
      left[i]         = NA_REAL;
      bottom[i]       = NA_REAL;
      right[i]        = NA_REAL;
      top[i]          = NA_REAL;
      contents[i]     = NA_STRING;
      title[i]        = NA_STRING;
      subject[i]      = NA_STRING;
      color_r[i] = color_g[i] = color_b[i] = color_a[i] = NA_REAL;
      interior_r[i] = interior_g[i] = interior_b[i] = interior_a[i] =
          NA_REAL;
      border_width[i] = NA_REAL;
      quad_points[i] = R_NilValue;
      vertices[i] = R_NilValue;
      ink_paths[i] = R_NilValue;
      font_color_r[i] = font_color_g[i] = font_color_b[i] = NA_REAL;
      font_size[i] = NA_REAL;
      popup_index[i] = NA_INTEGER;
      irt_index[i] = NA_INTEGER;
      file_attachment_name[i] = NA_STRING;
      continue;
    }
    subtype_code[i] = static_cast<int>(FPDFAnnot_GetSubtype(annot));
    flags[i]        = FPDFAnnot_GetFlags(annot);
    FS_RECTF rect;
    if (FPDFAnnot_GetRect(annot, &rect)) {
      left[i]   = rect.left;
      bottom[i] = rect.bottom;
      right[i]  = rect.right;
      top[i]    = rect.top;
    } else {
      left[i] = bottom[i] = right[i] = top[i] = NA_REAL;
    }
    contents[i] = read_annot_string(annot, "Contents");
    title[i]    = read_annot_string(annot, "T");
    subject[i]  = read_annot_string(annot, "Subj");
    double r, g, b, a;
    read_annot_color(annot, FPDFANNOT_COLORTYPE_Color, r, g, b, a);
    color_r[i] = r; color_g[i] = g; color_b[i] = b; color_a[i] = a;
    read_annot_color(annot, FPDFANNOT_COLORTYPE_InteriorColor,
                     r, g, b, a);
    interior_r[i] = r; interior_g[i] = g;
    interior_b[i] = b; interior_a[i] = a;
    // FPDFAnnot_GetBorder is only meaningful for annotation types
    // that carry a /Border entry (line/square/circle/polygon/
    // polyline). PDFium returns false otherwise; surface NA in
    // that case.
    float hor_radius = 0.f, ver_radius = 0.f, bw = 0.f;
    if (FPDFAnnot_GetBorder(annot, &hor_radius, &ver_radius, &bw)) {
      border_width[i] = bw;
    } else {
      border_width[i] = NA_REAL;
    }
    quad_points[i] = read_annot_quad_points(annot);
    vertices[i]    = read_annot_vertices(annot);
    ink_paths[i]   = read_annot_ink_paths(annot);
    // Font color / size: only meaningful for FreeText / Widget
    // annotations and require the form-fill env.
    if (form != nullptr) {
      unsigned int fr = 0, fg = 0, fb = 0;
      if (FPDFAnnot_GetFontColor(form, annot, &fr, &fg, &fb)) {
        font_color_r[i] = fr / 255.0;
        font_color_g[i] = fg / 255.0;
        font_color_b[i] = fb / 255.0;
      } else {
        font_color_r[i] = font_color_g[i] = font_color_b[i] = NA_REAL;
      }
      float fs = 0.f;
      font_size[i] = FPDFAnnot_GetFontSize(form, annot, &fs)
          ? static_cast<double>(fs) : NA_REAL;
    } else {
      font_color_r[i] = font_color_g[i] = font_color_b[i] = NA_REAL;
      font_size[i] = NA_REAL;
    }
    // Linked annotations: /Popup target (for sticky-note popups)
    // and /IRT target (in-reply-to, for comment threads).
    FPDF_ANNOTATION linked_popup =
        FPDFAnnot_GetLinkedAnnot(annot, "Popup");
    popup_index[i] = find_annot_index(page, linked_popup);
    if (popup_index[i] < 0) popup_index[i] = NA_INTEGER;
    if (linked_popup != nullptr) FPDFPage_CloseAnnot(linked_popup);
    FPDF_ANNOTATION linked_irt = FPDFAnnot_GetLinkedAnnot(annot, "IRT");
    irt_index[i] = find_annot_index(page, linked_irt);
    if (irt_index[i] < 0) irt_index[i] = NA_INTEGER;
    if (linked_irt != nullptr) FPDFPage_CloseAnnot(linked_irt);
    // FileAttachment annotation payload name (other subtypes get NA).
    if (FPDFAnnot_GetSubtype(annot) == FPDF_ANNOT_FILEATTACHMENT) {
      FPDF_ATTACHMENT att = FPDFAnnot_GetFileAttachment(annot);
      std::string name = read_attachment_name(att);
      if (name.empty()) {
        file_attachment_name[i] = NA_STRING;
      } else {
        file_attachment_name[i] = Rf_mkCharLenCE(
            name.data(), static_cast<int>(name.size()), CE_UTF8);
      }
    } else {
      file_attachment_name[i] = NA_STRING;
    }
    FPDFPage_CloseAnnot(annot);
  }
  if (form != nullptr) FPDFDOC_ExitFormFillEnvironment(form);
  return Rcpp::List::create(
      Rcpp::_["subtype_code"]  = subtype_code,
      Rcpp::_["flags"]         = flags,
      Rcpp::_["bounds_left"]   = left,
      Rcpp::_["bounds_bottom"] = bottom,
      Rcpp::_["bounds_right"]  = right,
      Rcpp::_["bounds_top"]    = top,
      Rcpp::_["contents"]      = contents,
      Rcpp::_["title"]         = title,
      Rcpp::_["subject"]       = subject,
      Rcpp::_["color_red"]     = color_r,
      Rcpp::_["color_green"]   = color_g,
      Rcpp::_["color_blue"]    = color_b,
      Rcpp::_["color_alpha"]   = color_a,
      Rcpp::_["interior_red"]   = interior_r,
      Rcpp::_["interior_green"] = interior_g,
      Rcpp::_["interior_blue"]  = interior_b,
      Rcpp::_["interior_alpha"] = interior_a,
      Rcpp::_["border_width"]  = border_width,
      Rcpp::_["quad_points"]   = quad_points,
      Rcpp::_["vertices"]      = vertices,
      Rcpp::_["ink_paths"]     = ink_paths,
      Rcpp::_["font_color_red"]   = font_color_r,
      Rcpp::_["font_color_green"] = font_color_g,
      Rcpp::_["font_color_blue"]  = font_color_b,
      Rcpp::_["font_size"]     = font_size,
      Rcpp::_["popup_index"]   = popup_index,
      Rcpp::_["irt_index"]     = irt_index,
      Rcpp::_["file_attachment_name"] = file_attachment_name);
}
