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

namespace {

FPDF_PAGEOBJECT obj_from_ptr(SEXP obj_ptr) {
  if (TYPEOF(obj_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page object.");
  }
  FPDF_PAGEOBJECT obj =
      static_cast<FPDF_PAGEOBJECT>(R_ExternalPtrAddr(obj_ptr));
  if (obj == nullptr) Rcpp::stop("Page-object handle is closed.");
  return obj;
}

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

// Convert a PDFium FPDF_BITMAP (any supported format) to a column-
// major IntegerMatrix where each pixel packs as ABGR per the
// nativeRaster convention. Caller owns destroying the source bitmap;
// this function does not.
Rcpp::IntegerMatrix bitmap_to_native_raster(FPDF_BITMAP bitmap) {
  int width  = FPDFBitmap_GetWidth(bitmap);
  int height = FPDFBitmap_GetHeight(bitmap);
  int stride = FPDFBitmap_GetStride(bitmap);
  int format = FPDFBitmap_GetFormat(bitmap);

  const uint8_t* buf =
      static_cast<const uint8_t*>(FPDFBitmap_GetBuffer(bitmap));
  if (buf == nullptr) Rcpp::stop("FPDFBitmap_GetBuffer returned NULL.");

  Rcpp::IntegerMatrix out(height, width);
  int* out_ptr = INTEGER(out);

  for (int y = 0; y < height; ++y) {
    const uint8_t* row = buf + static_cast<size_t>(y) * stride;
    for (int x = 0; x < width; ++x) {
      uint8_t r;
      uint8_t g;
      uint8_t b;
      uint8_t a = 255;
      switch (format) {
        case FPDFBitmap_Gray: {
          uint8_t v = row[x];
          r = g = b = v;
          break;
        }
        case FPDFBitmap_BGR: {
          b = row[x * 3 + 0];
          g = row[x * 3 + 1];
          r = row[x * 3 + 2];
          break;
        }
        case FPDFBitmap_BGRx: {
          b = row[x * 4 + 0];
          g = row[x * 4 + 1];
          r = row[x * 4 + 2];
          break;
        }
        case FPDFBitmap_BGRA: {
          b = row[x * 4 + 0];
          g = row[x * 4 + 1];
          r = row[x * 4 + 2];
          a = row[x * 4 + 3];
          break;
        }
        default:
          Rcpp::stop("Unsupported FPDFBitmap format: %d", format);
      }
      out_ptr[y + static_cast<size_t>(x) * height] =
          static_cast<int>(
              (static_cast<uint32_t>(a) << 24) |
              (static_cast<uint32_t>(b) << 16) |
              (static_cast<uint32_t>(g) <<  8) |
              (static_cast<uint32_t>(r)));
    }
  }
  return out;
}

}  // namespace

// [[Rcpp::export(name = "cpp_image_metadata")]]
Rcpp::List cpp_image_metadata(SEXP obj_ptr, SEXP page_ptr) {
  FPDF_PAGEOBJECT obj  = obj_from_ptr(obj_ptr);
  FPDF_PAGE       page = page_from_ptr(page_ptr);

  FPDF_IMAGEOBJ_METADATA m{};
  if (!FPDFImageObj_GetImageMetadata(obj, page, &m)) {
    Rcpp::stop("FPDFImageObj_GetImageMetadata failed; is this an image?");
  }
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
  if (!FPDFImageObj_GetImagePixelSize(obj, &w, &h)) {
    Rcpp::stop("FPDFImageObj_GetImagePixelSize failed.");
  }
  return Rcpp::IntegerVector::create(
      Rcpp::_["width"]  = static_cast<int>(w),
      Rcpp::_["height"] = static_cast<int>(h));
}

// [[Rcpp::export(name = "cpp_image_get_bitmap")]]
Rcpp::IntegerMatrix cpp_image_get_bitmap(SEXP obj_ptr) {
  FPDF_PAGEOBJECT obj = obj_from_ptr(obj_ptr);
  FPDF_BITMAP bitmap = FPDFImageObj_GetBitmap(obj);
  if (bitmap == nullptr) {
    Rcpp::stop("FPDFImageObj_GetBitmap returned NULL.");
  }
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
  if (bitmap == nullptr) {
    Rcpp::stop("FPDFImageObj_GetRenderedBitmap returned NULL.");
  }
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
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer for the page.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  // Two-pass byte protocol. The first call (NULL buffer) populates
  // `need` with the actual size required, returning FALSE.
  size_t need = 0;
  FPDFImageObj_GetIccProfileDataDecoded(obj, page, nullptr, 0, &need);
  if (need == 0) return Rcpp::RawVector(0);
  Rcpp::RawVector out(static_cast<R_xlen_t>(need));
  size_t got = 0;
  if (!FPDFImageObj_GetIccProfileDataDecoded(obj, page, &out[0], need,
                                              &got)) {
    return Rcpp::RawVector(0);
  }
  return out;
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
    if (needed == 0) {
      out[i] = "";
      continue;
    }
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
