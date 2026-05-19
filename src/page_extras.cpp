// pdfium R package — phase-6 page-level additions:
//
//   FPDFPage_GetMediaBox / CropBox / BleedBox / TrimBox / ArtBox
//                                     -> pdf_page_box(page, box=)
//   FPDFLink_Enumerate / FPDFLink_GetAnnotRect / FPDFLink_GetAction
//   FPDFAction_GetType / FPDFAction_GetURIPath
//   FPDFDest_GetDestPageIndex          -> pdf_page_links(page)
//
//   FPDFText_LoadPage / CountChars / GetUnicode / GetCharBox /
//   GetFontSize / IsGenerated / IsHyphen   -> pdf_text_chars(page)
//
// All three additions are page-level and take the page externalptr
// from R.

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_doc.h"
#include "fpdf_searchex.h"
#include "fpdf_text.h"
#include "fpdf_transformpage.h"
#include "action_helpers.h"
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

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the document.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) Rcpp::stop("Document handle is closed.");
  return doc;
}

}  // namespace

// [[Rcpp::export(name = "cpp_page_box")]]
Rcpp::NumericVector cpp_page_box(SEXP page_ptr, std::string box) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  float left = 0.f, bottom = 0.f, right = 0.f, top = 0.f;
  FPDF_BOOL ok = false;
  if (box == "media") {
    ok = FPDFPage_GetMediaBox(page, &left, &bottom, &right, &top);
  } else if (box == "crop") {
    ok = FPDFPage_GetCropBox(page, &left, &bottom, &right, &top);
  } else if (box == "bleed") {
    ok = FPDFPage_GetBleedBox(page, &left, &bottom, &right, &top);
  } else if (box == "trim") {
    ok = FPDFPage_GetTrimBox(page, &left, &bottom, &right, &top);
  } else if (box == "art") {
    ok = FPDFPage_GetArtBox(page, &left, &bottom, &right, &top);
  } else {
    Rcpp::stop("Unknown box `%s`. Must be one of "
               "\"media\", \"crop\", \"bleed\", \"trim\", \"art\".",
               box.c_str());
  }
  if (!ok) {
    return Rcpp::NumericVector::create(
        Rcpp::_["left"]   = NA_REAL,
        Rcpp::_["bottom"] = NA_REAL,
        Rcpp::_["right"]  = NA_REAL,
        Rcpp::_["top"]    = NA_REAL);
  }
  return Rcpp::NumericVector::create(
      Rcpp::_["left"]   = static_cast<double>(left),
      Rcpp::_["bottom"] = static_cast<double>(bottom),
      Rcpp::_["right"]  = static_cast<double>(right),
      Rcpp::_["top"]    = static_cast<double>(top));
}

// [[Rcpp::export(name = "cpp_page_links")]]
Rcpp::List cpp_page_links(SEXP doc_ptr, SEXP page_ptr) {
  FPDF_DOCUMENT doc  = doc_from_ptr(doc_ptr);
  FPDF_PAGE     page = page_from_ptr(page_ptr);
  std::vector<double> left, bottom, right, top;
  std::vector<int>    action_code;
  std::vector<std::string> uri;
  std::vector<std::string> filepath;
  std::vector<int>    dest_page;

  // FPDFLink_Enumerate iterates link annotations on the page. The
  // start_pos argument is an int in-out cursor PDFium updates.
  int pos = 0;
  FPDF_LINK link;
  while (FPDFLink_Enumerate(page, &pos, &link)) {
    FS_RECTF rect;
    if (FPDFLink_GetAnnotRect(link, &rect)) {
      left.push_back(rect.left);
      bottom.push_back(rect.bottom);
      right.push_back(rect.right);
      top.push_back(rect.top);
    } else {
      left.push_back(NA_REAL);
      bottom.push_back(NA_REAL);
      right.push_back(NA_REAL);
      top.push_back(NA_REAL);
    }
    FPDF_ACTION action = FPDFLink_GetAction(link);
    int code = 0, dest_idx = -1;
    std::string uri_text, fp_text;
    pdfium_r::classify_action(doc, action, code, uri_text, fp_text,
                              dest_idx);
    // Fall back to /Dest on the link itself for the no-/A case.
    if (action == nullptr) {
      FPDF_DEST dest = FPDFLink_GetDest(doc, link);
      if (dest != nullptr) {
        int p = FPDFDest_GetDestPageIndex(doc, dest);
        if (p >= 0) {
          dest_idx = p;
          code = PDFACTION_GOTO;
        }
      }
    }
    action_code.push_back(code);
    uri.emplace_back(uri_text);
    filepath.emplace_back(fp_text);
    dest_page.push_back(dest_idx < 0 ? NA_INTEGER : dest_idx + 1);
  }
  return Rcpp::List::create(
      Rcpp::_["bounds_left"]   = left,
      Rcpp::_["bounds_bottom"] = bottom,
      Rcpp::_["bounds_right"]  = right,
      Rcpp::_["bounds_top"]    = top,
      Rcpp::_["action_code"]   = action_code,
      Rcpp::_["uri"]           = uri,
      Rcpp::_["filepath"]      = filepath,
      Rcpp::_["dest_page_num"] = dest_page);
}

// [[Rcpp::export(name = "cpp_page_text_chars")]]
Rcpp::List cpp_page_text_chars(SEXP page_ptr) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) {
    Rcpp::stop("FPDFText_LoadPage returned NULL.");
  }
  int n = FPDFText_CountChars(tp);
  if (n < 0) n = 0;
  Rcpp::IntegerVector codepoint(n);
  Rcpp::CharacterVector ch(n);
  Rcpp::NumericVector left(n), bottom(n), right(n), top(n);
  Rcpp::NumericVector font_size(n);
  Rcpp::LogicalVector is_generated(n);
  Rcpp::LogicalVector is_hyphen(n);
  Rcpp::NumericVector origin_x(n), origin_y(n);
  Rcpp::NumericVector loose_left(n), loose_bottom(n),
                       loose_right(n), loose_top(n);
  Rcpp::LogicalVector unicode_map_error(n);
  Rcpp::IntegerVector text_index(n);
  for (int i = 0; i < n; ++i) {
    unsigned int cp = FPDFText_GetUnicode(tp, i);
    codepoint[i] = static_cast<int>(cp);
    // Encode the Unicode code point as a UTF-8 string. Surrogate
    // halves and the NUL sentinel come through as "" so downstream
    // string ops don't choke.
    if (cp == 0 || (cp >= 0xD800 && cp <= 0xDFFF)) {
      ch[i] = "";
    } else if (cp < 0x80) {
      char b[2] = { static_cast<char>(cp), 0 };
      ch[i] = std::string(b);
    } else {
      // Range-encode to UTF-8 manually so we don't pull in iconv.
      char b[5] = {0};
      if (cp < 0x800) {
        b[0] = 0xC0 | (cp >> 6);
        b[1] = 0x80 | (cp & 0x3F);
      } else if (cp < 0x10000) {
        b[0] = 0xE0 | (cp >> 12);
        b[1] = 0x80 | ((cp >> 6) & 0x3F);
        b[2] = 0x80 | (cp & 0x3F);
      } else if (cp < 0x110000) {
        b[0] = 0xF0 | (cp >> 18);
        b[1] = 0x80 | ((cp >> 12) & 0x3F);
        b[2] = 0x80 | ((cp >> 6) & 0x3F);
        b[3] = 0x80 | (cp & 0x3F);
      }
      ch[i] = std::string(b);
    }
    double l, b, r, t;
    if (FPDFText_GetCharBox(tp, i, &l, &r, &b, &t)) {
      left[i] = l; right[i] = r; bottom[i] = b; top[i] = t;
    } else {
      left[i] = right[i] = bottom[i] = top[i] = NA_REAL;
    }
    font_size[i]    = FPDFText_GetFontSize(tp, i);
    is_generated[i] = (FPDFText_IsGenerated(tp, i) != 0);
    is_hyphen[i]    = (FPDFText_IsHyphen(tp, i) != 0);
    double ox = 0, oy = 0;
    if (FPDFText_GetCharOrigin(tp, i, &ox, &oy)) {
      origin_x[i] = ox; origin_y[i] = oy;
    } else {
      origin_x[i] = NA_REAL; origin_y[i] = NA_REAL;
    }
    FS_RECTF lr;
    if (FPDFText_GetLooseCharBox(tp, i, &lr)) {
      loose_left[i] = lr.left;
      loose_bottom[i] = lr.bottom;
      loose_right[i] = lr.right;
      loose_top[i] = lr.top;
    } else {
      loose_left[i] = loose_bottom[i] = loose_right[i] =
          loose_top[i] = NA_REAL;
    }
    int err = FPDFText_HasUnicodeMapError(tp, i);
    unicode_map_error[i] = (err < 0) ? NA_LOGICAL : (err != 0);
    // FPDFText_GetTextIndexFromCharIndex returns -1 when the
    // character doesn't appear in the text page's "linear" text
    // (e.g. PDFium-synthesised whitespace). The R wrapper maps
    // negative values to NA_integer_.
    int ti = FPDFText_GetTextIndexFromCharIndex(tp, i);
    text_index[i] = (ti < 0) ? NA_INTEGER : ti;
  }
  FPDFText_ClosePage(tp);
  return Rcpp::List::create(
      Rcpp::_["codepoint"]    = codepoint,
      Rcpp::_["char"]         = ch,
      Rcpp::_["bounds_left"]  = left,
      Rcpp::_["bounds_bottom"]= bottom,
      Rcpp::_["bounds_right"] = right,
      Rcpp::_["bounds_top"]   = top,
      Rcpp::_["font_size"]    = font_size,
      Rcpp::_["is_generated"] = is_generated,
      Rcpp::_["is_hyphen"]    = is_hyphen,
      Rcpp::_["origin_x"]     = origin_x,
      Rcpp::_["origin_y"]     = origin_y,
      Rcpp::_["loose_left"]   = loose_left,
      Rcpp::_["loose_bottom"] = loose_bottom,
      Rcpp::_["loose_right"]  = loose_right,
      Rcpp::_["loose_top"]    = loose_top,
      Rcpp::_["unicode_map_error"] = unicode_map_error,
      Rcpp::_["text_index"]   = text_index);
}

// Hit-test: look up the 0-based character index at (x, y) in PDF
// user-space points, within xy_tolerance. Returns -1 when no char
// is near.
// [[Rcpp::export(name = "cpp_text_char_at_pos")]]
int cpp_text_char_at_pos(SEXP page_ptr, double x, double y,
                          double x_tol, double y_tol) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  int idx = FPDFText_GetCharIndexAtPos(tp, x, y, x_tol, y_tol);
  FPDFText_ClosePage(tp);
  return idx;
}

// Bidirectional index conversion. char_index <-> text_index, where
// char_index is the position in PDFium's "all characters" list
// (including synthesised whitespace) and text_index is the position
// in the "extractable text" string.
// [[Rcpp::export(name = "cpp_text_text_index_from_char")]]
int cpp_text_text_index_from_char(SEXP page_ptr, int char_index) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  int idx = FPDFText_GetTextIndexFromCharIndex(tp, char_index);
  FPDFText_ClosePage(tp);
  return idx;
}

// [[Rcpp::export(name = "cpp_text_char_index_from_text")]]
int cpp_text_char_index_from_text(SEXP page_ptr, int text_index) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_TEXTPAGE tp = FPDFText_LoadPage(page);
  if (tp == nullptr) Rcpp::stop("FPDFText_LoadPage returned NULL.");
  int idx = FPDFText_GetCharIndexFromTextIndex(tp, text_index);
  FPDFText_ClosePage(tp);
  return idx;
}
