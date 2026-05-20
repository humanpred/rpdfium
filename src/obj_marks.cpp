// pdfium R package — path draw mode + page-object content marks.
//
// Two related readouts that complete the v0.1.0 page-object surface:
//
//   FPDFPath_GetDrawMode(path, &fillmode, &stroke)
//                                  -> pdf_path_draw_mode(obj)
//   FPDFPageObj_CountMarks / GetMark / FPDFPageObjMark_GetName /
//   CountParams / GetParamKey / GetParamValueType /
//   GetParamIntValue / GetParamStringValue / GetParamBlobValue
//                                  -> pdf_obj_marks(obj)
//
// The mark readout returns one tibble row per content mark on the
// page object, with a list-column of named parameter values (numbers
// stay numeric, strings/names stay character, blobs come back as raw
// vectors). Writers in v0.2.0 can take the same shape back.

#include <Rcpp.h>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "utf16.h"

namespace {

FPDF_PAGEOBJECT marks_obj_from_ptr(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page object.");
  }
  FPDF_PAGEOBJECT obj =
      static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) Rcpp::stop("Page object handle is closed.");
  return obj;
}

// Read a UTF-16LE mark name. PDFium's GetName signature splits the
// byte protocol over two args: the FPDF_WCHAR buffer and an out
// pointer that reports the byte length actually written (including
// the trailing NUL). We pass a NULL buffer first to discover the
// needed length, then a real buffer the second time.
std::string read_mark_name(FPDF_PAGEOBJECTMARK mark) {
  unsigned long out_buflen = 0;
  if (!FPDFPageObjMark_GetName(mark, nullptr, 0, &out_buflen)) {
    return std::string();
  }
  if (out_buflen <= 2) return std::string();
  std::vector<unsigned short> buf(out_buflen / 2);
  if (!FPDFPageObjMark_GetName(mark, buf.data(), out_buflen,
                                &out_buflen)) {
    return std::string();
  }
  size_t wchars =
      (out_buflen >= 2 ? out_buflen / 2 - 1 : out_buflen / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// Read a single param key. PDFium returns the key as UTF-16LE
// (the byte length includes the trailing NUL pair). Convert to
// UTF-8 for use as the key in the C++ accessors below — PDFium's
// GetParamValueType / GetParamIntValue / GetParamStringValue /
// GetParamBlobValue all take a FPDF_BYTESTRING (UTF-8) key, so the
// round-trip through utf16le_to_utf8 is exactly the lookup PDFium
// performs internally.
std::string read_param_key(FPDF_PAGEOBJECTMARK mark,
                            unsigned long index) {
  unsigned long out_buflen = 0;
  if (!FPDFPageObjMark_GetParamKey(mark, index, nullptr, 0,
                                    &out_buflen)) {
    return std::string();
  }
  if (out_buflen <= 2) return std::string();
  std::vector<unsigned short> buf(out_buflen / 2);
  if (!FPDFPageObjMark_GetParamKey(mark, index, buf.data(),
                                    out_buflen, &out_buflen)) {
    return std::string();
  }
  size_t wchars =
      (out_buflen >= 2 ? out_buflen / 2 - 1 : out_buflen / 2);
  return pdfium_r::utf16le_to_utf8(buf.data(), wchars);
}

// Read a single param value as an R SEXP. The selector is the value
// type PDFium reports; unsupported types map to NA.
SEXP read_param_value(FPDF_PAGEOBJECTMARK mark, const std::string& key) {
  int type = FPDFPageObjMark_GetParamValueType(mark, key.c_str());
  if (type == FPDF_OBJECT_NUMBER) {
    int out = 0;
    if (FPDFPageObjMark_GetParamIntValue(mark, key.c_str(), &out)) {
      return Rcpp::wrap(out);
    }
    return Rcpp::wrap(NA_INTEGER);
  }
  if (type == FPDF_OBJECT_STRING || type == FPDF_OBJECT_NAME) {
    unsigned long out_buflen = 0;
    if (!FPDFPageObjMark_GetParamStringValue(mark, key.c_str(),
                                              nullptr, 0,
                                              &out_buflen)) {
      return Rcpp::wrap(NA_STRING);
    }
    if (out_buflen <= 2) return Rcpp::wrap(std::string());
    std::vector<unsigned short> buf(out_buflen / 2);
    if (!FPDFPageObjMark_GetParamStringValue(
            mark, key.c_str(), buf.data(), out_buflen, &out_buflen)) {
      return Rcpp::wrap(NA_STRING);
    }
    size_t wchars = (out_buflen >= 2 ? out_buflen / 2 - 1
                                       : out_buflen / 2);
    return Rcpp::wrap(pdfium_r::utf16le_to_utf8(buf.data(), wchars));
  }
  // Blob: surface as a raw vector. PDFium's blob accessor returns
  // raw bytes (no NUL-termination protocol).
  unsigned long out_buflen = 0;
  if (FPDFPageObjMark_GetParamBlobValue(mark, key.c_str(), nullptr,
                                         0, &out_buflen)) {
    if (out_buflen == 0) return Rcpp::RawVector(0);
    Rcpp::RawVector blob(static_cast<R_xlen_t>(out_buflen));
    if (FPDFPageObjMark_GetParamBlobValue(mark, key.c_str(),
                                           RAW(blob), out_buflen,
                                           &out_buflen)) {
      return blob;
    }
  }
  return R_NilValue;
}

}  // namespace

// Path draw mode: returns whether the path is stroked and what fill
// mode (none / alternate ("even_odd") / winding) is in effect.
// PDFium codes: FPDF_FILLMODE_NONE = 0, _ALTERNATE = 1, _WINDING = 2.
// [[Rcpp::export(name = "cpp_path_draw_mode")]]
Rcpp::List cpp_path_draw_mode(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = marks_obj_from_ptr(obj_ptr);
  int fillmode = 0;
  FPDF_BOOL stroke = 0;
  if (!FPDFPath_GetDrawMode(obj, &fillmode, &stroke)) {
    return Rcpp::List::create(
        Rcpp::_["fill_mode_code"] = NA_INTEGER,
        Rcpp::_["stroke"]         = NA_LOGICAL);
  }
  return Rcpp::List::create(
      Rcpp::_["fill_mode_code"] = fillmode,
      Rcpp::_["stroke"]         = static_cast<bool>(stroke));
}

// Page-object content marks. Each row is one mark; `params` is a
// named list of the mark's key/value pairs (the inner R type depends
// on the value's PDFium type).
// [[Rcpp::export(name = "cpp_obj_marks_list")]]
Rcpp::List cpp_obj_marks_list(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = marks_obj_from_ptr(obj_ptr);
  int n_marks = FPDFPageObj_CountMarks(obj);
  if (n_marks < 0) n_marks = 0;
  Rcpp::CharacterVector names(n_marks);
  Rcpp::List params(n_marks);
  for (int i = 0; i < n_marks; ++i) {
    FPDF_PAGEOBJECTMARK mark = FPDFPageObj_GetMark(obj, i);
    if (mark == nullptr) {
      names[i] = NA_STRING;
      params[i] = R_NilValue;
      continue;
    }
    names[i] = read_mark_name(mark);
    int n_params = FPDFPageObjMark_CountParams(mark);
    if (n_params < 0) n_params = 0;
    Rcpp::List one(n_params);
    Rcpp::CharacterVector param_names(n_params);
    for (int j = 0; j < n_params; ++j) {
      std::string key = read_param_key(mark, j);
      param_names[j] = key;
      one[j] = read_param_value(mark, key);
    }
    one.attr("names") = param_names;
    params[i] = one;
  }
  return Rcpp::List::create(
      Rcpp::_["name"]   = names,
      Rcpp::_["params"] = params);
}
