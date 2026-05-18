// pdfium R package — UTF-16LE <-> UTF-8 conversion shared between
// the text-extraction (src/text.cpp), document-metadata
// (src/document.cpp), and text-search (src/text_search.cpp) layers.
// PDFium's FPDFTextObj_GetText / FPDF_GetMetaText / FPDFText_GetText
// emit UTF-16LE under the same byte-counted size protocol;
// FPDFText_FindStart consumes a NUL-terminated UTF-16LE query.

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

// Convert a UTF-8 std::string to a NUL-terminated UTF-16LE buffer
// suitable for passing as FPDF_WIDESTRING. Malformed UTF-8 bytes are
// skipped silently — search queries originate from R user code where
// validation is upstream (`enc2utf8()` + length checks).
inline std::vector<unsigned short> utf8_to_utf16le_nul(const std::string& s) {
  std::vector<unsigned short> out;
  out.reserve(s.size() + 1);
  size_t i = 0;
  while (i < s.size()) {
    unsigned char c = static_cast<unsigned char>(s[i]);
    unsigned int cp = 0;
    int extra = 0;
    if (c < 0x80) {
      cp = c;
    } else if ((c & 0xE0) == 0xC0) {
      cp = c & 0x1F;
      extra = 1;
    } else if ((c & 0xF0) == 0xE0) {
      cp = c & 0x0F;
      extra = 2;
    } else if ((c & 0xF8) == 0xF0) {
      cp = c & 0x07;
      extra = 3;
    } else {
      ++i;
      continue;  // invalid leading byte, drop
    }
    ++i;
    bool valid = true;
    for (int k = 0; k < extra; ++k) {
      if (i >= s.size()) {
        valid = false;
        break;
      }
      unsigned char cn = static_cast<unsigned char>(s[i]);
      if ((cn & 0xC0) != 0x80) {
        valid = false;
        break;
      }
      cp = (cp << 6) | (cn & 0x3F);
      ++i;
    }
    if (!valid) continue;
    if (cp < 0x10000) {
      out.push_back(static_cast<unsigned short>(cp));
    } else {
      cp -= 0x10000;
      out.push_back(static_cast<unsigned short>(0xD800 + (cp >> 10)));
      out.push_back(static_cast<unsigned short>(0xDC00 + (cp & 0x3FF)));
    }
  }
  out.push_back(0);  // NUL terminator required by FPDF_WIDESTRING
  return out;
}

}  // namespace pdfium_r

#endif  // PDFIUM_R_PKG_UTF16_H
