// pdfium R package — page-object creators (Phase 5).
//
// PDFium's creation API splits over three calls per object:
//
//   1. Create the FPDF_PAGEOBJECT (FPDFPageObj_CreateNewPath /
//      _CreateNewRect / _NewTextObj / _NewImageObj). The object is
//      "detached" — it exists in memory but is not on any page.
//   2. (Optional) populate it (text content, image data, etc.).
//   3. Insert into a page (FPDFPage_InsertObject), which transfers
//      ownership: the page will FPDFPageObj_Destroy it when the page
//      closes.
//
// All creators in this file do the create + insert in one shot so
// the R wrapper never has to manage a detached-object lifetime. The
// returned externalptr has NO finalizer because the page owns the
// object now; closing the page (via the page's externalptr
// finalizer) is what triggers cleanup. The prot slot pins the
// page externalptr — same lifetime model as `cpp_page_get_object`
// in src/objects.cpp.
//
// pdf_obj_delete is the inverse: it removes the object from its
// page, destroys the C++ object, AND clears the R externalptr so
// subsequent calls on the same handle error cleanly via the
// existing is_open() chain (handle_validation.h, ADR-020 §4).

#include <Rcpp.h>
#include <string>
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

inline FPDF_PAGEOBJECT obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

// Wrap a freshly-inserted FPDF_PAGEOBJECT as an externalptr with
// the page externalptr pinned in `prot`. No finalizer — page owns
// the object now.
SEXP wrap_attached_obj(FPDF_PAGEOBJECT obj, SEXP page_ptr) {
  return R_MakeExternalPtr(obj, R_NilValue, page_ptr);
}

}  // namespace

// [[Rcpp::export(name = "cpp_path_new")]]
SEXP cpp_path_new(SEXP page_ptr, double x, double y) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_PAGEOBJECT path = FPDFPageObj_CreateNewPath(
      static_cast<float>(x), static_cast<float>(y));
  if (path == nullptr) {
    Rcpp::stop("FPDFPageObj_CreateNewPath returned NULL.");
  }
  FPDFPage_InsertObject(page, path);
  return wrap_attached_obj(path, page_ptr);
}

// [[Rcpp::export(name = "cpp_rect_new")]]
SEXP cpp_rect_new(SEXP page_ptr, double x, double y,
                    double width, double height) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_PAGEOBJECT rect = FPDFPageObj_CreateNewRect(
      static_cast<float>(x), static_cast<float>(y),
      static_cast<float>(width), static_cast<float>(height));
  if (rect == nullptr) {
    Rcpp::stop("FPDFPageObj_CreateNewRect returned NULL.");
  }
  FPDFPage_InsertObject(page, rect);
  return wrap_attached_obj(rect, page_ptr);
}

// [[Rcpp::export(name = "cpp_text_new")]]
SEXP cpp_text_new(SEXP doc_ptr, SEXP page_ptr,
                    std::string font_name, double font_size,
                    std::string text_utf8,
                    double x, double y) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_PAGEOBJECT text_obj = FPDFPageObj_NewTextObj(
      doc, font_name.c_str(), static_cast<float>(font_size));
  if (text_obj == nullptr) {
    Rcpp::stop(
        "FPDFPageObj_NewTextObj returned NULL — is `%s` a valid "
        "PDF standard font?", font_name.c_str());
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
  // Position via FPDFPageObj_Transform (identity scale + translate).
  FPDFPageObj_Transform(text_obj, 1, 0, 0, 1,
                         static_cast<float>(x),
                         static_cast<float>(y));
  FPDFPage_InsertObject(page, text_obj);
  return wrap_attached_obj(text_obj, page_ptr);
}

// Remove the object from its page and destroy it. The R-side
// externalptr is cleared so subsequent is_open() checks return
// FALSE, making the R wrapper's existing close-state errors
// surface uniformly across mutators.
// [[Rcpp::export(name = "cpp_obj_delete")]]
bool cpp_obj_delete(SEXP page_ptr, SEXP obj_ptr) {
  FPDF_PAGE page = page_from_ptr(page_ptr);
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  if (!FPDFPage_RemoveObject(page, obj)) {
    return false;
  }
  FPDFPageObj_Destroy(obj);
  R_ClearExternalPtr(obj_ptr);
  return true;
}
