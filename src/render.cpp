// pdfium R package — page rendering to a nativeRaster-compatible
// integer matrix.
//
// FPDF_RenderPageBitmap renders the page into a PDFium FPDF_BITMAP
// allocated with FPDFBitmap_BGRA: in-memory byte order per pixel is
// B, G, R, A. We translate to R's `nativeRaster` integer encoding
// where each pixel packs as
//
//     int = (A << 24) | (B << 16) | (G << 8) | R
//
// (little-endian byte order: R, G, B, A). The output is an
// IntegerMatrix whose dim is c(height, width) - same shape that
// grDevices::as.raster and grid::rasterGrob expect.

#include <Rcpp.h>
#include <cstdint>
#include "fpdfview.h"

// [[Rcpp::export(name = "cpp_render_page")]]
Rcpp::IntegerMatrix cpp_render_page(SEXP page_ptr,
                                    int pixel_width,
                                    int pixel_height,
                                    int rotation_code,
                                    int render_flags,
                                    int background_argb,
                                    bool fill_background) {
  if (TYPEOF(page_ptr) != EXTPTRSXP) {
    Rcpp::stop("Expected an external pointer.");
  }
  FPDF_PAGE page = static_cast<FPDF_PAGE>(R_ExternalPtrAddr(page_ptr));
  if (page == nullptr) Rcpp::stop("Page handle is closed.");
  if (pixel_width  <= 0) Rcpp::stop("pixel_width must be positive.");
  if (pixel_height <= 0) Rcpp::stop("pixel_height must be positive.");

  FPDF_BITMAP bitmap = FPDFBitmap_Create(pixel_width, pixel_height,
                                         /*alpha=*/1);
  if (bitmap == nullptr) {
    Rcpp::stop("FPDFBitmap_Create returned NULL (likely out of memory).");
  }

  // FPDFBitmap_FillRect interprets `color` as 0xAARRGGBB regardless
  // of the bitmap's byte order. When `fill_background` is FALSE the
  // backing buffer remains zero-initialized (fully transparent).
  if (fill_background) {
    FPDFBitmap_FillRect(bitmap, 0, 0, pixel_width, pixel_height,
                        background_argb);
  }

  FPDF_RenderPageBitmap(bitmap, page,
                        /*start_x=*/0, /*start_y=*/0,
                        pixel_width, pixel_height,
                        rotation_code, render_flags);

  const uint8_t* buf =
      static_cast<const uint8_t*>(FPDFBitmap_GetBuffer(bitmap));
  int stride = FPDFBitmap_GetStride(bitmap);

  Rcpp::IntegerMatrix out(pixel_height, pixel_width);
  int* out_ptr = INTEGER(out);
  for (int y = 0; y < pixel_height; ++y) {
    const uint8_t* row = buf + static_cast<size_t>(y) * stride;
    for (int x = 0; x < pixel_width; ++x) {
      uint8_t b = row[x * 4 + 0];
      uint8_t g = row[x * 4 + 1];
      uint8_t r = row[x * 4 + 2];
      uint8_t a = row[x * 4 + 3];
      // Column-major storage: m[y, x] sits at index y + x*nrow.
      out_ptr[y + static_cast<size_t>(x) * pixel_height] =
          static_cast<int>(
              (static_cast<uint32_t>(a) << 24) |
              (static_cast<uint32_t>(b) << 16) |
              (static_cast<uint32_t>(g) <<  8) |
              (static_cast<uint32_t>(r)));
    }
  }

  FPDFBitmap_Destroy(bitmap);
  return out;
}
