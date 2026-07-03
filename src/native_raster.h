// pdfium R package — shared FPDF_BITMAP -> R nativeRaster conversion.
//
// PDFium renders into an FPDF_BITMAP whose in-memory byte order per
// pixel is B, G, R, A (FPDFBitmap_BGRA) — or one of the narrower
// FPDFBitmap_{Gray, BGR, BGRx} formats. R's `nativeRaster` class
// packs each pixel into a single 32-bit int as
//
//     int = (A << 24) | (B << 16) | (G << 8) | R
//
// (i.e. little-endian byte order R, G, B, A).
//
// STORAGE ORDER — the load-bearing subtlety this header exists to get
// right. A genuine R `nativeRaster` (the object `png::readPNG(native =
// TRUE)` returns) has `dim = c(height, width)` but its backing
// integer buffer is laid out ROW-MAJOR: element k holds the pixel at
// (row = k / width, col = k % width). That is the OPPOSITE of a
// standard R `matrix(integer, ...)`, which is column-major. Because
// `pdfium_bitmap` inherits from `nativeRaster`, every consumer that
// trusts that class — `png::writePNG()`, `grid::grid.raster()`, R's
// graphics engine — reads the buffer row-major. If we wrote it
// column-major (as a plain R matrix would be) those consumers shear
// every row sideways ("stride-streak garbage"): the historical
// pdfium-render defect the figureextract ecosystem worked around.
//
// So `fill_native_raster_rowmajor` writes ROW-MAJOR, making the
// object a *conformant* nativeRaster. `as.array()` / `as.raster()`
// unpack it with the matching row-major convention.

#ifndef PDFIUM_R_NATIVE_RASTER_H_
#define PDFIUM_R_NATIVE_RASTER_H_

#include <Rcpp.h>
#include <cstdint>
#include "fpdfview.h"

namespace pdfium_r {

// Pack one BGRA pixel's channels into R's ABGR nativeRaster int.
inline int abgr_int(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  return static_cast<int>(
      (static_cast<uint32_t>(a) << 24) |
      (static_cast<uint32_t>(b) << 16) |
      (static_cast<uint32_t>(g) <<  8) |
      (static_cast<uint32_t>(r)));
}

// Fill an already-allocated IntegerMatrix `out` (dim c(height, width))
// from a 4-byte-per-pixel BGRA FPDF_BITMAP buffer, honoring the
// per-row stride and writing ROW-MAJOR so the result is a conformant
// nativeRaster (see file header). `out` must have exactly
// height * width elements.
//
// `stride` is the bitmap's byte stride (>= width * 4); it may exceed
// width*4 due to row padding, so we index each row from
// `buf + y * stride` rather than assuming a contiguous buffer.
inline void fill_bgra_rowmajor(int* out_ptr, const uint8_t* buf,
                               int width, int height, int stride) {
  for (int y = 0; y < height; ++y) {
    const uint8_t* row = buf + static_cast<size_t>(y) * stride;
    int* out_row = out_ptr + static_cast<size_t>(y) * width;
    for (int x = 0; x < width; ++x) {
      uint8_t b = row[x * 4 + 0];
      uint8_t g = row[x * 4 + 1];
      uint8_t r = row[x * 4 + 2];
      uint8_t a = row[x * 4 + 3];
      out_row[x] = abgr_int(r, g, b, a);
    }
  }
}

// Fill `out` (dim c(height, width)) ROW-MAJOR from an FPDF_BITMAP in
// any of PDFium's four pixel formats. `format` is FPDFBitmap_GetFormat.
// Opaque formats (Gray / BGR / BGRx) get alpha = 255. Unsupported
// formats raise (a future PDFium ABI change surfaces as a clear error
// rather than a silent out-of-bounds read). Honors per-row `stride`.
inline void fill_bitmap_rowmajor(int* out_ptr, const uint8_t* buf,
                                 int width, int height, int stride,
                                 int format) {
  for (int y = 0; y < height; ++y) {
    const uint8_t* row = buf + static_cast<size_t>(y) * stride;
    int* out_row = out_ptr + static_cast<size_t>(y) * width;
    for (int x = 0; x < width; ++x) {
      uint8_t r;
      uint8_t g;
      uint8_t b;
      uint8_t a = 255;
      switch (format) {
        // # nocov start — Cairo emits BGR for image.pdf and BGRA for
        // FPDFImageObj_GetRenderedBitmap; the Gray / BGRx branches
        // require non-Cairo fixtures (8-bit grayscale or
        // pre-alpha-stripped sources) we do not ship.
        case FPDFBitmap_Gray: {
          uint8_t v = row[x];
          r = g = b = v;
          break;
        }
        // # nocov end
        case FPDFBitmap_BGR: {
          b = row[x * 3 + 0];
          g = row[x * 3 + 1];
          r = row[x * 3 + 2];
          break;
        }
        // # nocov start — see Gray-branch note above.
        case FPDFBitmap_BGRx: {
          b = row[x * 4 + 0];
          g = row[x * 4 + 1];
          r = row[x * 4 + 2];
          break;
        }
        // # nocov end
        case FPDFBitmap_BGRA: {
          b = row[x * 4 + 0];
          g = row[x * 4 + 1];
          r = row[x * 4 + 2];
          a = row[x * 4 + 3];
          break;
        }
        default:
          // # nocov start — PDFium only ever emits the four formats
          // above; the default arm exists so a future ABI change
          // surfaces as a clear error, not a silent OOB read.
          Rcpp::stop("Unsupported FPDFBitmap format: %d", format);
          // # nocov end
      }
      out_row[x] = abgr_int(r, g, b, a);
    }
  }
}

}  // namespace pdfium_r

#endif  // PDFIUM_R_NATIVE_RASTER_H_
