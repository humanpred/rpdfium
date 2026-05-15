// pdfium R package — UTF-16LE -> UTF-8 conversion shared between
// the text-extraction (src/text.cpp) and document-metadata
// (src/document.cpp) layers. PDFium's FPDFTextObj_GetText and
// FPDF_GetMetaText both emit UTF-16LE and follow the same
// byte-counted size protocol.

#ifndef PDFIUM_R_PKG_UTF16_H
#define PDFIUM_R_PKG_UTF16_H

#include <string>
#include <vector>

namespace pdfium_r {

// Convert a buffer of n UTF-16LE code units to a UTF-8 std::string.
// Handles BMP code points and high/low surrogate pairs. Skips NULs
// (PDFium's getters include a trailing NUL in the reported size).
inline std::string utf16le_to_utf8(const unsigned short* buf, size_t n) {
  std::string out;
  out.reserve(n);
  for (size_t i = 0; i < n; ++i) {
    unsigned int cp = buf[i];
    if (cp == 0) continue;  // skip embedded NULs defensively
    if (cp >= 0xD800 && cp < 0xDC00 && i + 1 < n) {
      unsigned int low = buf[i + 1];
      if (low >= 0xDC00 && low < 0xE000) {
        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
        ++i;
      }
    }
    if (cp < 0x80) {
      out.push_back(static_cast<char>(cp));
    } else if (cp < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
  }
  return out;
}

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_UTF16_H
