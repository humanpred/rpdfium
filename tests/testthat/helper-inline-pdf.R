# Test helpers that build small PDFs from raw object syntax, for
# tests that need a PDF feature the checked-in fixtures don't carry.
# Sourced into every testthat worker.

# Assemble a PDF from object bodies: `objs[[i]]` becomes object `i`
# (generation 0) and object 1 must be the catalog. Returns the file
# bytes as a raw vector, ready for `pdf_doc_open(source = ...)`.
inline_pdf_bytes <- function(objs) {
  out <- "%PDF-1.7\n"
  offs <- integer(length(objs))
  for (i in seq_along(objs)) {
    offs[[i]] <- nchar(out, "bytes")
    out <- paste0(out, i, " 0 obj\n", objs[[i]], "\nendobj\n")
  }
  xref <- nchar(out, "bytes")
  charToRaw(paste0(
    out, "xref\n0 ", length(objs) + 1L, "\n0000000000 65535 f \n",
    paste0(sprintf("%010d 00000 n \n", offs), collapse = ""),
    "trailer\n<< /Size ", length(objs) + 1L, " /Root 1 0 R >>\n",
    "startxref\n", xref, "\n%%EOF\n"
  ))
}

# Body of a stream object: `dict` holds the dictionary entries (without
# `<<` / `>>`); `/Length` is filled in from `content`.
inline_pdf_stream <- function(dict, content) {
  sprintf("<< %s /Length %d >>\nstream\n%s\nendstream",
          dict, nchar(content, "bytes"), content)
}

# One page whose content stream strokes a single path built with each
# cubic Bezier operator: `c` (both control points given), `v` (first
# control point = current point) and `y` (second control point =
# endpoint).
inline_curves_pdf <- function() {
  inline_pdf_bytes(c(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] ",
           "/Contents 4 0 R >>"),
    inline_pdf_stream(
      "",
      "10 10 m 20 30 40 50 60 70 c 80 90 100 110 v 120 130 140 150 y S"
    )
  ))
}
