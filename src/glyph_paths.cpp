// pdfium R package — glyph outlines, font metrics, and per-char
// font info. These un-defer the v0.1.0 Tier 3 items the user
// explicitly needs for "challenging character mapping" workflows
// (detecting bad ToUnicode CMaps, comparing rendered glyphs to
// expected unicode glyphs, etc.).
//
// Glyph-path API surface:
//
//   FPDFTextObj_GetFont(text_obj)              -> FPDF_FONT
//   FPDFFont_GetGlyphPath(font, glyph, size)   -> FPDF_GLYPHPATH
//     FPDFGlyphPath_CountGlyphSegments
//     FPDFGlyphPath_GetGlyphPathSegment        -> per-segment walk
//   FPDFFont_GetGlyphWidth(font, glyph, size, &out)
//   FPDFFont_GetAscent(font, font_size, &ascent)
//   FPDFFont_GetDescent(font, font_size, &descent)
//
// Per-character font info:
//   FPDFText_LoadPage + FPDFText_GetFontInfo(tp, idx, buf, buflen,
//                                             &flags)

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "fpdf_text.h"
#include "handle_validation.h"

namespace {

FPDF_PAGEOBJECT gp_obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

FPDF_PAGE gp_page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

}  // namespace

// Returns a tibble of (segment_type, x, y, close_figure) for the
// glyph at `glyph_code` in the text object's font, rendered at
// `font_size` in PDF user-space points. Returns an empty tibble
// when the font / glyph combination has no outline.
//
// `glyph_code` interpretation depends on the font type. For most
// TrueType fonts with /Identity-H or unicode-CMap encoding the
// glyph code equals the unicode code point; for Type 1 fonts it
// is the encoding-specific character code. Users investigating
// challenging mappings typically pass either the unicode they
// observed on the page or enumerate small integer codes to find
// the rendered glyph.
// [[Rcpp::export(name = "cpp_text_obj_glyph_path")]]
Rcpp::List cpp_text_obj_glyph_path(SEXP obj_ptr,
                                    int glyph_code,
                                    double font_size) {
  FPDF_PAGEOBJECT obj = gp_obj_from_ptr(obj_ptr);
  FPDF_FONT font = FPDFTextObj_GetFont(obj);
  if (font == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["segment_type"] = Rcpp::IntegerVector(),
        Rcpp::_["x"]            = Rcpp::NumericVector(),
        Rcpp::_["y"]            = Rcpp::NumericVector(),
        Rcpp::_["close"]        = Rcpp::LogicalVector());
  }
  // If the caller passed NA / NaN font_size, fall back to the
  // object's actual font size.
  float fs = static_cast<float>(font_size);
  if (!R_finite(font_size) || font_size <= 0) {
    float obj_fs = 0.f;
    if (FPDFTextObj_GetFontSize(obj, &obj_fs)) fs = obj_fs;
    else fs = 1.f;
  }
  FPDF_GLYPHPATH gp = FPDFFont_GetGlyphPath(
      font, static_cast<uint32_t>(glyph_code), fs);
  if (gp == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["segment_type"] = Rcpp::IntegerVector(),
        Rcpp::_["x"]            = Rcpp::NumericVector(),
        Rcpp::_["y"]            = Rcpp::NumericVector(),
        Rcpp::_["close"]        = Rcpp::LogicalVector());
  }
  int n = FPDFGlyphPath_CountGlyphSegments(gp);
  if (n < 0) n = 0;
  Rcpp::IntegerVector seg_type(n);
  Rcpp::NumericVector x(n), y(n);
  Rcpp::LogicalVector close(n);
  for (int i = 0; i < n; ++i) {
    FPDF_PATHSEGMENT seg = FPDFGlyphPath_GetGlyphPathSegment(gp, i);
    if (seg == nullptr) {
      seg_type[i] = NA_INTEGER;
      x[i] = NA_REAL; y[i] = NA_REAL;
      close[i] = NA_LOGICAL;
      continue;
    }
    seg_type[i] = FPDFPathSegment_GetType(seg);
    float px = 0, py = 0;
    if (FPDFPathSegment_GetPoint(seg, &px, &py)) {
      x[i] = px; y[i] = py;
    } else {
      x[i] = NA_REAL; y[i] = NA_REAL;
    }
    close[i] = (FPDFPathSegment_GetClose(seg) != 0);
  }
  return Rcpp::List::create(
      Rcpp::_["segment_type"] = seg_type,
      Rcpp::_["x"]            = x,
      Rcpp::_["y"]            = y,
      Rcpp::_["close"]        = close);
}

// Width of a glyph in PDF user-space points at `font_size`. NA when
// PDFium reports failure or `font` is null.
// [[Rcpp::export(name = "cpp_text_obj_glyph_width")]]
double cpp_text_obj_glyph_width(SEXP obj_ptr, int glyph_code,
                                 double font_size) {
  FPDF_PAGEOBJECT obj = gp_obj_from_ptr(obj_ptr);
  FPDF_FONT font = FPDFTextObj_GetFont(obj);
  if (font == nullptr) return NA_REAL;
  float fs = static_cast<float>(font_size);
  if (!R_finite(font_size) || font_size <= 0) {
    float obj_fs = 0.f;
    if (FPDFTextObj_GetFontSize(obj, &obj_fs)) fs = obj_fs;
    else fs = 1.f;
  }
  float w = 0.f;
  if (!FPDFFont_GetGlyphWidth(font, static_cast<uint32_t>(glyph_code),
                               fs, &w)) {
    return NA_REAL;
  }
  return static_cast<double>(w);
}

// Ascent + descent in PDF user-space points at the requested font
// size. Either / both are NA when PDFium can't resolve them.
// [[Rcpp::export(name = "cpp_text_obj_font_metrics")]]
Rcpp::List cpp_text_obj_font_metrics(SEXP obj_ptr, double font_size) {
  FPDF_PAGEOBJECT obj = gp_obj_from_ptr(obj_ptr);
  FPDF_FONT font = FPDFTextObj_GetFont(obj);
  if (font == nullptr) {
    return Rcpp::List::create(
        Rcpp::_["ascent"]  = NA_REAL,
        Rcpp::_["descent"] = NA_REAL);
  }
  float fs = static_cast<float>(font_size);
  if (!R_finite(font_size) || font_size <= 0) fs = 1.f;
  float asc = 0.f, dsc = 0.f;
  double a = NA_REAL, d = NA_REAL;
  if (FPDFFont_GetAscent(font, fs, &asc))  a = asc;
  if (FPDFFont_GetDescent(font, fs, &dsc)) d = dsc;
  return Rcpp::List::create(
      Rcpp::_["ascent"]  = a,
      Rcpp::_["descent"] = d);
}

// Per-character font name + flags. PDFium reports both via one
// call; the R wrapper exposes them as two new columns on
// pdf_text_chars (in src/page_extras.cpp).
// [[Rcpp::export(name = "cpp_text_char_font_info")]]
Rcpp::List cpp_text_char_font_info(SEXP page_ptr) {
  FPDF_PAGE page = gp_page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  int n = FPDFText_CountChars(tp);
  if (n < 0) n = 0;
  Rcpp::CharacterVector font_name(n);
  Rcpp::IntegerVector   font_flags(n);
  for (int i = 0; i < n; ++i) {
    int flags = 0;
    unsigned long needed =
        FPDFText_GetFontInfo(tp, i, nullptr, 0, &flags);
    if (needed <= 1) {
      font_name[i] = "";
      font_flags[i] = NA_INTEGER;
      continue;
    }
    std::vector<char> buf(needed);
    FPDFText_GetFontInfo(tp, i, buf.data(), needed, &flags);
    // PDFium null-terminates the buffer; strip.
    size_t len = (needed > 0 && buf[needed - 1] == '\0')
                     ? needed - 1 : needed;
    font_name[i] = std::string(buf.data(), len);
    font_flags[i] = flags;
  }
  FPDFText_ClosePage(tp);
  return Rcpp::List::create(
      Rcpp::_["font_name"]  = font_name,
      Rcpp::_["font_flags"] = font_flags);
}
