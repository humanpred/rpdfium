// pdfium R package — image page-object extraction.
//
// PDFium exposes embedded raster images in three useful forms:
//
//   1. Decoded pixel bitmap (FPDFImageObj_GetBitmap) - the image as
//      decoded by PDFium, ignoring any page-level transformation.
//   2. Rendered bitmap (FPDFImageObj_GetRenderedBitmap) - the image
//      with the page CTM applied; matches what you'd see in a viewer.
//   3. Raw stream bytes (FPDFImageObj_GetImageDataDecoded /
//      FPDFImageObj_GetImageDataRaw) - either the uncompressed pixel
//      data, or the raw embedded stream (the original JPEG/JBIG2/etc.
//      bytes) for callers that want to save the source asset
//      verbatim.
//
// The two bitmap entrypoints return an FPDF_BITMAP whose format may
// be any of FPDFBitmap_{Gray, BGR, BGRx, BGRA}. We translate all
// four formats to R's `nativeRaster` ABGR packed-int encoding
// (alpha=FF for opaque formats) so the resulting IntegerMatrix can
// be wrapped in the same `pdfium_bitmap` S3 class that page
// rendering produces.
//
// FPDF_PAGEOBJECT lifetime is owned by its parent FPDF_PAGE, so
// these functions take the obj+page externalptr pair (and the doc
// for GetRenderedBitmap) and assume the parent handles are still
// open - the R wrappers check that before calling in.

#include <Rcpp.h>
#include <cstdint>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_edit.h"
#include "handle_validation.h"
#include "native_raster.h"

namespace {

FPDF_PAGEOBJECT obj_from_ptr(SEXP obj_ptr) {
  return static_cast<FPDF_PAGEOBJECT>(
      pdfium_r::validate_handle(obj_ptr, "Page-object",
                                  /*require_prot_alive=*/true));
}

FPDF_PAGE page_from_ptr(SEXP page_ptr) {
  return static_cast<FPDF_PAGE>(
      pdfium_r::validate_handle(page_ptr, "Page",
                                  /*require_prot_alive=*/false));
}

FPDF_DOCUMENT doc_from_ptr(SEXP doc_ptr) {
  return static_cast<FPDF_DOCUMENT>(
      pdfium_r::validate_handle(doc_ptr, "Document",
                                  /*require_prot_alive=*/false));
}

// Convert a PDFium FPDF_BITMAP (any supported format) to an
// IntegerMatrix (dim c(height, width)) filled ROW-MAJOR so it is a
// conformant nativeRaster (each pixel packs as ABGR). See
// native_raster.h for the storage-order rationale. Caller owns
// destroying the source bitmap; this function does not.
Rcpp::IntegerMatrix bitmap_to_native_raster(FPDF_BITMAP bitmap) {
  int width  = FPDFBitmap_GetWidth(bitmap);
  int height = FPDFBitmap_GetHeight(bitmap);
  int stride = FPDFBitmap_GetStride(bitmap);
  int format = FPDFBitmap_GetFormat(bitmap);

  const uint8_t* buf =
      static_cast<const uint8_t*>(FPDFBitmap_GetBuffer(bitmap));
  if (buf == nullptr) Rcpp::stop("FPDFBitmap_GetBuffer returned NULL.");

  Rcpp::IntegerMatrix out(height, width);
  pdfium_r::fill_bitmap_rowmajor(INTEGER(out), buf,
                                 width, height, stride, format);
  return out;
}

}  // namespace

// [[Rcpp::export(name = "cpp_image_metadata")]]
Rcpp::List cpp_image_metadata(SEXP obj_ptr, SEXP page_ptr) {
  FPDF_PAGEOBJECT obj  = obj_from_ptr(obj_ptr);
  FPDF_PAGE       page = page_from_ptr(page_ptr);

  FPDF_IMAGEOBJ_METADATA m{};
  if (!FPDFImageObj_GetImageMetadata(obj, page, &m)) {  // # nocov start
    // FPDFImageObj_GetImageMetadata only fails when `obj` is not an
    // image-typed page object; the R wrapper validates the type via
    // check_image_obj() before the call, so this branch is
    // unreachable from the public API.
    Rcpp::stop("FPDFImageObj_GetImageMetadata failed; is this an image?");
  }  // # nocov end
  return Rcpp::List::create(
      Rcpp::_["width"]             = static_cast<int>(m.width),
      Rcpp::_["height"]            = static_cast<int>(m.height),
      Rcpp::_["horizontal_dpi"]    = static_cast<double>(m.horizontal_dpi),
      Rcpp::_["vertical_dpi"]      = static_cast<double>(m.vertical_dpi),
      Rcpp::_["bits_per_pixel"]    = static_cast<int>(m.bits_per_pixel),
      Rcpp::_["colorspace"]        = static_cast<int>(m.colorspace),
      Rcpp::_["marked_content_id"] = m.marked_content_id);
}

// [[Rcpp::export(name = "cpp_image_pixel_size")]]
Rcpp::IntegerVector cpp_image_pixel_size(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  unsigned int w = 0;
  unsigned int h = 0;
  if (!FPDFImageObj_GetImagePixelSize(obj, &w, &h)) {  // # nocov start
    // Same as cpp_image_metadata above: FPDFImageObj_GetImagePixelSize
    // only fails on a non-image obj, which check_image_obj() filters
    // out before we get here.
    Rcpp::stop("FPDFImageObj_GetImagePixelSize failed.");
  }  // # nocov end
  return Rcpp::IntegerVector::create(
      Rcpp::_["width"]  = static_cast<int>(w),
      Rcpp::_["height"] = static_cast<int>(h));
}

// [[Rcpp::export(name = "cpp_image_get_bitmap")]]
Rcpp::IntegerMatrix cpp_image_get_bitmap(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  FPDF_BITMAP bitmap = FPDFImageObj_GetBitmap(obj);
  if (bitmap == nullptr) {  // # nocov start
    // FPDFImageObj_GetBitmap returns NULL when the image stream is
    // malformed (un-decodable filter, missing /ColorSpace entry).
    // Every image we ship in fixtures decodes successfully, so this
    // branch is unreachable from our test corpus.
    Rcpp::stop("FPDFImageObj_GetBitmap returned NULL.");
  }  // # nocov end
  Rcpp::IntegerMatrix out = bitmap_to_native_raster(bitmap);
  FPDFBitmap_Destroy(bitmap);
  return out;
}

// [[Rcpp::export(name = "cpp_image_get_rendered_bitmap")]]
Rcpp::IntegerMatrix cpp_image_get_rendered_bitmap(SEXP doc_ptr,
                                                  SEXP page_ptr,
                                                  SEXP obj_ptr) {
  FPDF_DOCUMENT   doc  = doc_from_ptr(doc_ptr);
  FPDF_PAGE       page = page_from_ptr(page_ptr);
  FPDF_PAGEOBJECT obj  = obj_from_ptr(obj_ptr);
  FPDF_BITMAP bitmap = FPDFImageObj_GetRenderedBitmap(doc, page, obj);
  if (bitmap == nullptr) {  // # nocov start
    // Same failure mode as cpp_image_get_bitmap above: only triggers
    // on a malformed image stream PDFium cannot render. Every shipped
    // image fixture renders successfully.
    Rcpp::stop("FPDFImageObj_GetRenderedBitmap returned NULL.");
  }  // # nocov end
  Rcpp::IntegerMatrix out = bitmap_to_native_raster(bitmap);
  FPDFBitmap_Destroy(bitmap);
  return out;
}

// [[Rcpp::export(name = "cpp_image_data")]]
Rcpp::RawVector cpp_image_data(SEXP obj_ptr, bool decoded) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  // Two-pass: query required length with NULL buffer, then allocate
  // and fill on the second call.
  unsigned long needed =
      decoded ? FPDFImageObj_GetImageDataDecoded(obj, nullptr, 0)
              : FPDFImageObj_GetImageDataRaw(obj, nullptr, 0);
  Rcpp::RawVector out(static_cast<R_xlen_t>(needed));
  if (needed > 0) {
    if (decoded) {
      FPDFImageObj_GetImageDataDecoded(obj, &out[0], needed);
    } else {
      FPDFImageObj_GetImageDataRaw(obj, &out[0], needed);
    }
  }
  return out;
}

// [[Rcpp::export(name = "cpp_image_icc_profile")]]
Rcpp::RawVector cpp_image_icc_profile(SEXP obj_ptr, SEXP page_ptr) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  if (TYPEOF(page_ptr) != EXTPTRSXP) {  // # nocov start
    // The R wrapper (pdf_image_icc_profile) always passes
    // obj$page$ptr, which is the externalptr stored on the parent
    // pdfium_page handle — never a non-externalptr SEXP. Defensive
    // guard kept so a direct .Call from user code gets a clear
    // message instead of a segfault inside R_ExternalPtrAddr.
    Rcpp::stop("Expected an external pointer for the page.");
  }  // # nocov end
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  // Two-pass byte protocol. The first call (NULL buffer) populates
  // `need` with the actual size required, returning FALSE.
  size_t need = 0;
  FPDFImageObj_GetIccProfileDataDecoded(obj, page, nullptr, 0, &need);
  if (need == 0) return Rcpp::RawVector(0);
  // # nocov start — Cairo emits /DeviceRGB for image.pdf, and no
  // other shipped fixture carries an /ICCBased colour space, so the
  // non-empty branch and the second-pass failure are unreachable
  // from the test corpus. Authoring a fixture with an embedded ICC
  // profile would require a non-Cairo writer; the dispatch shape
  // mirrors the standard PDFium two-pass byte protocol.
  Rcpp::RawVector out(static_cast<R_xlen_t>(need));
  size_t got = 0;
  if (!FPDFImageObj_GetIccProfileDataDecoded(obj, page, &out[0], need,
                                              &got)) {
    return Rcpp::RawVector(0);
  }
  return out;
  // # nocov end
}

// [[Rcpp::export(name = "cpp_image_filters")]]
Rcpp::CharacterVector cpp_image_filters(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  int n = FPDFImageObj_GetImageFilterCount(obj);
  if (n < 0) return Rcpp::CharacterVector(0);

  Rcpp::CharacterVector out(n);
  for (int i = 0; i < n; ++i) {
    // PDFium-style two-pass: ask for length (returns size including
    // the NUL terminator), allocate, then fill.
    unsigned long needed = FPDFImageObj_GetImageFilter(obj, i, nullptr, 0);
    if (needed == 0) {  // # nocov start
      // FPDFImageObj_GetImageFilter returns 0 only when the filter
      // index is out of range or the filter entry is somehow empty —
      // neither happens for the in-range indices [0, n) we iterate
      // over here, since FPDFImageObj_GetImageFilterCount reports the
      // exact count above.
      out[i] = "";
      continue;
    }  // # nocov end
    std::vector<char> buf(needed);
    FPDFImageObj_GetImageFilter(obj, i, buf.data(), needed);
    // Strip the trailing NUL if present.
    size_t len = (needed > 0 && buf[needed - 1] == '\0')
                     ? (needed - 1)
                     : needed;
    out[i] = std::string(buf.data(), len);
  }
  return out;
}
