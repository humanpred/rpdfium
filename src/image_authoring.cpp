// pdfium R package — image-object creation from JPEG bytes.
//
// Wraps the FPDFImageObj_LoadJpegFileInline path. PDFium's LoadJpeg*
// API takes an FPDF_FILEACCESS callback structure; for our use case
// (load a single in-memory buffer up front, copy it into the PDF),
// the callback is a thin memcpy from a static buffer we own for the
// duration of the call.
//
// LoadJpegFileInline vs LoadJpegFile: the "inline" variant tells
// PDFium to copy the JPEG bytes into the PDF immediately rather
// than holding a reference to the FileAccess for later reads.
// That's what we want — the R-side raw vector that backs our
// FileAccess struct is only valid for the lifetime of this call.

#include <Rcpp.h>
#include <cstring>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"

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

// FPDF_FILEACCESS callback. Reads bytes from the buffer held in
// `param` (which we set to point at a JpegBuf). Returns 1 on
// success (PDFium's docs say "non-zero if successful").
struct JpegBuf {
  const unsigned char* data;
  unsigned long len;
};

int read_jpeg_block(void* param, unsigned long position,
                    unsigned char* p_buf, unsigned long size) {
  JpegBuf* jb = static_cast<JpegBuf*>(param);
  if (position + size > jb->len) {
    return 0;  // # nocov  // PDFium reads within jb->len it queried on the previous step
  }
  std::memcpy(p_buf, jb->data + position, size);
  return 1;
}

}  // namespace

// [[Rcpp::export(name = "cpp_image_new_from_jpeg")]]
SEXP cpp_image_new_from_jpeg(SEXP doc_ptr, SEXP page_ptr,
                              Rcpp::RawVector jpeg_bytes) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_PAGE page = page_from_ptr(page_ptr);

  FPDF_PAGEOBJECT image_obj = FPDFPageObj_NewImageObj(doc);
  if (image_obj == nullptr) {
    Rcpp::stop("FPDFPageObj_NewImageObj returned NULL.");  // # nocov  // only fails on out-of-memory
  }

  JpegBuf jb;
  jb.data = reinterpret_cast<const unsigned char*>(
      jpeg_bytes.size() > 0 ? &jpeg_bytes[0] : nullptr);
  jb.len = static_cast<unsigned long>(jpeg_bytes.size());

  FPDF_FILEACCESS file_access;
  file_access.m_FileLen = jb.len;
  file_access.m_GetBlock = read_jpeg_block;
  file_access.m_Param = &jb;

  // The "inline" variant copies the bytes into the PDF up front,
  // so jb only needs to outlive this call. (LoadJpegFile, without
  // the "Inline" suffix, retains a reference to file_access and
  // would dangle on return.)
  FPDF_PAGE pages[] = {page};
  if (!FPDFImageObj_LoadJpegFileInline(pages, 1, image_obj,  // # nocov start  // PDFium accepts any bytes (parses lazily); the FileAccess callback only fails on the OOM path
                                         &file_access)) {
    FPDFPageObj_Destroy(image_obj);
    Rcpp::stop("FPDFImageObj_LoadJpegFileInline failed; the bytes "
               "may not be valid JPEG.");
  }  // # nocov end

  FPDFPage_InsertObject(page, image_obj);

  // No finalizer: the page owns the object now (PDFium will destroy
  // it when the page closes). The externalptr's prot slot pins the
  // page so handle_validation can detect a closed parent.
  return R_MakeExternalPtr(image_obj, R_NilValue, page_ptr);
}

// [[Rcpp::export(name = "cpp_image_set_matrix")]]
bool cpp_image_set_matrix(SEXP image_ptr,
                           double a, double b, double c, double d,
                           double e, double f) {
  FPDF_PAGEOBJECT image_obj = static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(image_ptr, "Image object",
                                  /*require_prot_alive=*/true));
  return FPDFImageObj_SetMatrix(image_obj, a, b, c, d, e, f) != 0;
}

// Create a blank image page-object (no encoded stream attached), insert
// it into the page, and return its handle. The caller follows up with
// FPDFImageObj_SetBitmap (cpp_image_set_bitmap) to attach pixel data,
// then sets the matrix. Pairs with pdf_image_new_from_bitmap on the R
// side as the bitmap counterpart to cpp_image_new_from_jpeg.
// [[Rcpp::export(name = "cpp_image_new_blank")]]
SEXP cpp_image_new_blank(SEXP doc_ptr, SEXP page_ptr) {
  FPDF_DOCUMENT doc = doc_from_ptr(doc_ptr);
  FPDF_PAGE page = page_from_ptr(page_ptr);

  FPDF_PAGEOBJECT image_obj = FPDFPageObj_NewImageObj(doc);
  if (image_obj == nullptr) {
    // # nocov start — FPDFPageObj_NewImageObj returns NULL only on
    // OOM at the PDF dict-allocation level; PDFium's chromium/7202
    // binary is reliable on the test sizes we exercise.
    Rcpp::stop("FPDFPageObj_NewImageObj returned NULL.");
    // # nocov end
  }

  FPDFPage_InsertObject(page, image_obj);

  // No finalizer: page owns the object now. prot pins the page.
  return R_MakeExternalPtr(image_obj, R_NilValue, page_ptr);
}
