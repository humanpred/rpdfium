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

# One page with a stamp annotation whose appearance stream holds one
# object of each type PDFium parses: a filled rectangle, a "Hi" text
# run, a 1x1 inline image, an axial shading and the Form XObject /Fm,
# which draws a "Nested" text run. The page's own content draws /Fm
# as well.
inline_annot_objects_pdf <- function() {
  inline_pdf_bytes(c(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] ",
           "/Resources << /XObject << /Fm 7 0 R >> >> ",
           "/Contents 9 0 R /Annots [4 0 R] >>"),
    paste0("<< /Type /Annot /Subtype /Stamp /Rect [0 0 100 100] ",
           "/AP << /N 5 0 R >> >>"),
    inline_pdf_stream(
      paste("/Type /XObject /Subtype /Form /BBox [0 0 100 100]",
            "/Resources << /Font << /F1 6 0 R >> /XObject << /Fm 7 0 R >>",
            "/Shading << /Sh 8 0 R >> >>"),
      paste("1 0 0 rg 10 10 30 30 re f",
            "BT /F1 12 Tf 10 60 Td (Hi) Tj ET",
            "q 10 0 0 10 50 10 cm",
            "BI /W 1 /H 1 /CS /G /BPC 8 /F /AHx ID ff> EI Q",
            "q /Sh sh Q",
            "q 1 0 0 1 60 60 cm /Fm Do Q",
            sep = "\n")
    ),
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    inline_pdf_stream(
      paste("/Type /XObject /Subtype /Form /BBox [0 0 50 50]",
            "/Resources << /Font << /F1 6 0 R >> >>"),
      "BT /F1 10 Tf 0 0 Td (Nested) Tj ET"
    ),
    paste("<< /ShadingType 2 /ColorSpace /DeviceRGB /Coords [0 0 100 0]",
          "/Function << /FunctionType 2 /Domain [0 1] /C0 [1 0 0]",
          "/C1 [0 0 1] /N 1 >> >>"),
    inline_pdf_stream("", "q 1 0 0 1 100 100 cm /Fm Do Q")
  ))
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

# Content that paints a red 100 x 100 square clipped to the 50 x 50
# square at (10, 10), so the square's path object carries a one-sub-path
# clip path.
inline_clipped_rect <- "q 10 10 50 50 re W n 1 0 0 rg 0 0 100 100 re f Q"

# One page that paints `inline_clipped_rect` and then draws the Form
# XObject /Fm, which paints it too: the page's objects are the clipped
# path and the form, whose one child is a clipped path.
inline_clip_pdf <- function() {
  inline_pdf_bytes(c(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] ",
           "/Resources << /XObject << /Fm 5 0 R >> >> /Contents 4 0 R >>"),
    inline_pdf_stream("", paste(inline_clipped_rect, "/Fm Do")),
    inline_pdf_stream("/Type /XObject /Subtype /Form /BBox [0 0 100 100]",
                      inline_clipped_rect)
  ))
}

# One page that draws a chain of `depth` Form XObjects, each drawing
# the next one; the innermost paints `inline_clipped_rect`.
inline_nested_forms_pdf <- function(depth) {
  forms <- vapply(seq_len(depth), function(i) {
    if (i == depth) {
      return(inline_pdf_stream(
        "/Type /XObject /Subtype /Form /BBox [0 0 100 100]",
        inline_clipped_rect
      ))
    }
    inline_pdf_stream(
      sprintf(paste("/Type /XObject /Subtype /Form /BBox [0 0 100 100]",
                    "/Resources << /XObject << /Fm %d 0 R >> >>"), i + 5L),
      "/Fm Do"
    )
  }, character(1L))
  inline_pdf_bytes(c(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] ",
           "/Resources << /XObject << /Fm 5 0 R >> >> /Contents 4 0 R >>"),
    inline_pdf_stream("", "/Fm Do"),
    forms
  ))
}
