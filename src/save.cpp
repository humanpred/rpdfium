// pdfium R package — save / write surface.
//
// Wraps FPDF_SaveAsCopy and FPDF_SaveWithVersion via a small
// FPDF_FILEWRITE adapter. Two output sinks are exposed:
//
//   * cpp_save_to_file(doc_ptr, path, flags, version) — streams
//     PDFium's output into a std::ofstream. The R caller ensures
//     atomicity by pointing `path` at a tempfile in the destination
//     directory and renaming on success.
//   * cpp_save_to_raw(doc_ptr, flags, version) — accumulates PDFium's
//     output into a std::vector<uint8_t> and returns the bytes to R
//     as a raw vector.
//
// PDFium's FPDF_FILEWRITE protocol is one virtual call:
//   int WriteBlock(FPDF_FILEWRITE* this_, const void* data,
//                  unsigned long size)
// returning 1 on success / 0 on failure. We embed each sink in a
// struct whose first member is the PDFium-defined FPDF_FILEWRITE
// base, so the WriteBlock thunk can downcast cleanly.

#include <Rcpp.h>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>
#include "fpdfview.h"
#include "fpdf_save.h"

namespace {

struct FileWriter : FPDF_FILEWRITE {
  std::ofstream* stream;
  bool ok;
};

struct RawWriter : FPDF_FILEWRITE {
  std::vector<uint8_t>* bytes;
};

int file_write_block(FPDF_FILEWRITE* base, const void* data,
                     unsigned long size) {
  FileWriter* self = static_cast<FileWriter*>(base);
  if (!self->ok || self->stream == nullptr) return 0;
  self->stream->write(static_cast<const char*>(data),
                      static_cast<std::streamsize>(size));
  if (!*self->stream) {
    self->ok = false;
    return 0;
  }
  return 1;
}

int raw_write_block(FPDF_FILEWRITE* base, const void* data,
                    unsigned long size) {
  RawWriter* self = static_cast<RawWriter*>(base);
  if (self->bytes == nullptr) return 0;
  const uint8_t* p = static_cast<const uint8_t*>(data);
  self->bytes->insert(self->bytes->end(), p, p + size);
  return 1;
}

FPDF_DOCUMENT doc_from_xptr(SEXP doc_ptr) {
  if (TYPEOF(doc_ptr) != EXTPTRSXP) {
    Rcpp::stop("doc_ptr is not an externalptr.");
  }
  FPDF_DOCUMENT doc =
      static_cast<FPDF_DOCUMENT>(R_ExternalPtrAddr(doc_ptr));
  if (doc == nullptr) {
    Rcpp::stop("Document handle is NULL (was the doc closed?).");
  }
  return doc;
}

} // namespace

// [[Rcpp::export(name = "cpp_save_to_file")]]
bool cpp_save_to_file(SEXP doc_ptr, std::string path,
                      int flags, int version) {
  FPDF_DOCUMENT doc = doc_from_xptr(doc_ptr);

  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) {
    Rcpp::stop("Cannot open `%s` for writing.", path.c_str());
  }

  FileWriter fw{};
  fw.version = 1;
  fw.WriteBlock = file_write_block;
  fw.stream = &out;
  fw.ok = true;

  FPDF_BOOL ok;
  if (version <= 0) {
    ok = FPDF_SaveAsCopy(doc, &fw, static_cast<FPDF_DWORD>(flags));
  } else {
    ok = FPDF_SaveWithVersion(doc, &fw,
                              static_cast<FPDF_DWORD>(flags), version);
  }
  out.close();
  return ok && fw.ok;
}

// [[Rcpp::export(name = "cpp_save_to_raw")]]
Rcpp::RawVector cpp_save_to_raw(SEXP doc_ptr, int flags, int version) {
  FPDF_DOCUMENT doc = doc_from_xptr(doc_ptr);

  std::vector<uint8_t> bytes;
  bytes.reserve(64 * 1024);

  RawWriter rw{};
  rw.version = 1;
  rw.WriteBlock = raw_write_block;
  rw.bytes = &bytes;

  FPDF_BOOL ok;
  if (version <= 0) {
    ok = FPDF_SaveAsCopy(doc, &rw, static_cast<FPDF_DWORD>(flags));
  } else {
    ok = FPDF_SaveWithVersion(doc, &rw,
                              static_cast<FPDF_DWORD>(flags), version);
  }
  if (!ok) {
    Rcpp::stop("PDFium FPDF_Save* returned failure.");
  }

  Rcpp::RawVector out(bytes.size());
  if (!bytes.empty()) {
    std::memcpy(&out[0], bytes.data(), bytes.size());
  }
  return out;
}
