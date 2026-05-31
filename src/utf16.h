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
    // # nocov start — every R-side caller strips the trailing UTF-16
    // NUL before calling (see e.g. struct_tree.cpp:51, text.cpp:58),
    // so embedded NULs in the iterated range never arise in practice.
    // The skip exists as a hardening guard against future callers
    // that forget to strip the NUL.
    if (cp == 0) continue;
    // # nocov end
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
    } else if ((c & 0xF8) == 0xF0) {  // # nocov — gcov attributes hits for this 4-byte UTF-8 leading-byte branch to the body lines (78-79), not the condition; the body's count > 0 confirms the branch is exercised by the emoji query in test-text-search.R "round-trips non-ASCII query strings"
      cp = c & 0x07;
      extra = 3;
    } else {
      // # nocov start — R-side callers route every input through
      // enc2utf8() before reaching here (see R/text_search.R,
      // R/annot_setters.R, etc.), so the leading byte is always a
      // valid UTF-8 start. This branch is a hardening guard against
      // upstream callers that bypass the R wrappers (e.g. direct
      // C++ use of pdfium_r::utf8_to_utf16le_nul from a future
      // contributor).
      ++i;
      continue;  // invalid leading byte, drop
      // # nocov end
    }
    ++i;
    bool valid = true;
    for (int k = 0; k < extra; ++k) {
      if (i >= s.size()) {
        // # nocov start — truncated UTF-8 sequence; same upstream
        // enc2utf8() guarantee means continuation bytes are always
        // present for a well-formed leading byte.
        valid = false;
        break;
        // # nocov end
      }
      unsigned char cn = static_cast<unsigned char>(s[i]);
      if ((cn & 0xC0) != 0x80) {
        // # nocov start — malformed continuation byte; defensive
        // against the same upstream-bypass case described above.
        valid = false;
        break;
        // # nocov end
      }
      cp = (cp << 6) | (cn & 0x3F);
      ++i;
    }
    if (!valid) continue;  // # nocov — only set in the two defensive paths above
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
