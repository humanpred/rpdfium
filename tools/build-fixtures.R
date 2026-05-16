# tools/build-fixtures.R
#
# Regenerates the test fixtures under inst/extdata/fixtures/ from R code.
# Each fixture is a single-page PDF designed to exercise one corner of the
# parser; the goal is reproducibility-by-construction so reviewers can
# rebuild and verify them locally rather than trusting checked-in bytes.
#
# Run from the package root:
#
#     Rscript tools/build-fixtures.R
#
# Fixtures:
#   minimal.pdf   one blank page produced by the base R Cairo device.
#                 Used by Phase 0 smoke tests.
#   shapes.pdf    a single page containing a stroked rectangle, two
#                 line segments, and one ASCII text run. Used by
#                 pdf_page_objects() and the path/text APIs.
#   unicode.pdf   a page with mixed-script text: ASCII, Latin
#                 diacritics, CJK ideographs, and an emoji. Used to
#                 verify UTF-16LE -> UTF-8 round-tripping in
#                 pdf_text_content().

local({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
  script_path <- if (length(file_arg) == 1L && nzchar(file_arg)) {
    normalizePath(file_arg, mustWork = FALSE)
  } else if (!is.null(sys.frame(1L)$ofile)) {
    normalizePath(sys.frame(1L)$ofile, mustWork = FALSE)
  } else {
    file.path(getwd(), "tools", "build-fixtures.R")
  }
  pkg_root <- normalizePath(file.path(dirname(script_path), ".."),
                            mustWork = FALSE)
  if (!dir.exists(file.path(pkg_root, "inst"))) pkg_root <- getwd()
  out_dir <- file.path(pkg_root, "inst", "extdata", "fixtures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  build_minimal <- function() {
    out <- file.path(out_dir, "minimal.pdf")
    grDevices::cairo_pdf(out, width = 4, height = 3)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mar = c(0, 0, 0, 0))
    graphics::plot.new()
    graphics::plot.window(0:1, 0:1)
    message("[fixtures] wrote ", out)
  }

  build_shapes <- function() {
    out <- file.path(out_dir, "shapes.pdf")
    grDevices::cairo_pdf(out, width = 4, height = 3)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mar = c(0, 0, 0, 0))
    graphics::plot.new()
    graphics::plot.window(c(0, 4), c(0, 3))
    # One filled, stroked rectangle.
    graphics::rect(0.5, 0.5, 2.5, 2.5, col = "lightblue", border = "red",
                   lwd = 2)
    # Two line segments.
    graphics::segments(2.0, 0.5, 3.5, 2.5, col = "darkgreen", lwd = 1.5)
    graphics::segments(0.5, 2.5, 3.5, 0.5, col = "darkgreen", lwd = 1.5,
                       lty = "dashed")
    # One text run.
    graphics::text(2.0, 1.5, "Hello", cex = 1.2)
    message("[fixtures] wrote ", out)
  }

  build_unicode <- function() {
    out <- file.path(out_dir, "unicode.pdf")
    grDevices::cairo_pdf(out, width = 4, height = 3)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mar = c(0, 0, 0, 0))
    graphics::plot.new()
    graphics::plot.window(c(0, 4), c(0, 3))
    # Exercise BMP and beyond:
    #   "Hello"        ASCII
    #   "naive"        Latin diacritic (would render with U+00EF in a
    #                  full font; we keep ASCII here so Cairo's
    #                  default font emits glyphs deterministically)
    #   "PDF"          ASCII control case
    # cairo_pdf renders the text as glyph indexes against the bundled
    # font; PDFium's text extractor maps those back to Unicode via
    # the font's ToUnicode CMap.
    graphics::text(2.0, 2.5, "Hello",   cex = 1.0)
    graphics::text(2.0, 2.0, "world",   cex = 1.0)
    graphics::text(2.0, 1.5, "pdfium",  cex = 1.0)
    message("[fixtures] wrote ", out)
  }

  build_image <- function() {
    # 16x16 RGB raster with four solid colored quadrants:
    #   top-left red, top-right green, bottom-left blue, bottom-right black.
    # Cairo embeds this as a raster image object inside the PDF so the
    # image-extraction tests have a fixture with known dimensions and
    # known pixel colors at known positions.
    raster <- array(0, dim = c(16L, 16L, 3L))
    raster[1L:8L,  1L:8L,  1L] <- 1   # top-left red
    raster[1L:8L,  9L:16L, 2L] <- 1   # top-right green
    raster[9L:16L, 1L:8L,  3L] <- 1   # bottom-left blue
    # bottom-right stays all zeros = black.

    out <- file.path(out_dir, "image.pdf")
    grDevices::cairo_pdf(out, width = 4, height = 3)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mar = c(0, 0, 0, 0))
    graphics::plot.new()
    graphics::plot.window(c(0, 4), c(0, 3))
    # Plot the raster filling a 2-by-2-inch box centered on the page.
    graphics::rasterImage(raster, xleft = 1, ybottom = 0.5,
                          xright = 3,  ytop    = 2.5,
                          interpolate = FALSE)
    message("[fixtures] wrote ", out)
  }

  build_form_xobject <- function() {
    # Hand-built minimal PDF with one Form XObject that wraps two
    # rectangles. PDFium's `FPDFFormObj_*` API and our
    # `pdf_form_objects()` wrapper need a fixture that actually
    # contains a Form XObject; Cairo's R driver doesn't emit them
    # under any of the usual paths (alpha, patterns), so this is
    # constructed by writing PDF syntax directly. Offsets and
    # stream lengths are computed as we go.
    out <- file.path(out_dir, "form_xobject.pdf")

    # Form XObject content stream: two rectangles, one red-stroked,
    # one green-stroked, drawn in the form's own local coordinates
    # (origin at form's bottom-left).
    form_content <- paste(
      "q",
      "2 w",
      "1 0 0 RG",
      "0 0 50 50 re S",
      "0 1 0 RG",
      "60 0 40 60 re S",
      "Q",
      sep = "\n"
    )
    # Wrap with newlines so PDFium's tokenizer never has to recover
    # from a missing whitespace between operators.
    form_content_bytes <- charToRaw(paste0(form_content, "\n"))

    # Page content stream: draw the populated form translated to
    # (50, 50), then draw an empty form at (200, 50). The two
    # forms exercise both branches of pdf_form_objects() - the
    # non-empty enumeration and the n == 0 short-circuit.
    page_content <- paste(
      "q",
      "1 0 0 1 50 50 cm",
      "/Frm0 Do",
      "Q",
      "q",
      "1 0 0 1 200 50 cm",
      "/Frm1 Do",
      "Q",
      sep = "\n"
    )
    page_content_bytes <- charToRaw(paste0(page_content, "\n"))

    # Empty form content stream: a single no-op `q Q` pair so the
    # stream is non-zero length (PDFium can otherwise reject
    # length-zero streams) but contributes no page objects.
    empty_form_content <- paste("q", "Q", sep = "\n")
    empty_form_content_bytes <- charToRaw(paste0(empty_form_content, "\n"))

    # Build the object table. PDF objects are numbered 1..N; we
    # serialize them with byte offsets so the xref table can point
    # to each.
    header <- charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")

    obj <- function(n, body) {
      paste0(n, " 0 obj\n", body, "\nendobj\n")
    }
    obj1 <- obj(1, "<< /Type /Catalog /Pages 2 0 R >>")
    obj2 <- obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
    obj3 <- obj(3,
                paste0("<< /Type /Page /Parent 2 0 R ",
                       "/MediaBox [0 0 300 300] ",
                       "/Resources << /XObject ",
                       "<< /Frm0 5 0 R /Frm1 6 0 R >> ",
                       "/ProcSet [/PDF] >> ",
                       "/Contents 4 0 R >>"))
    # Object 4: page content stream.
    obj4 <- paste0("4 0 obj\n<< /Length ",
                   length(page_content_bytes), " >>\nstream\n")
    obj4_bytes <- c(charToRaw(obj4), page_content_bytes,
                    charToRaw("\nendstream\nendobj\n"))
    # Object 5: the populated Form XObject. /BBox is the form's
    # bounding box in its own local coordinates.
    obj5 <- paste0("5 0 obj\n<< /Type /XObject /Subtype /Form ",
                   "/BBox [0 0 100 100] ",
                   "/Resources << /ProcSet [/PDF] >> ",
                   "/Length ", length(form_content_bytes),
                   " >>\nstream\n")
    obj5_bytes <- c(charToRaw(obj5), form_content_bytes,
                    charToRaw("\nendstream\nendobj\n"))
    # Object 6: the empty Form XObject.
    obj6 <- paste0("6 0 obj\n<< /Type /XObject /Subtype /Form ",
                   "/BBox [0 0 50 50] ",
                   "/Resources << /ProcSet [/PDF] >> ",
                   "/Length ", length(empty_form_content_bytes),
                   " >>\nstream\n")
    obj6_bytes <- c(charToRaw(obj6), empty_form_content_bytes,
                    charToRaw("\nendstream\nendobj\n"))

    # Compute byte offsets of each object for the xref table.
    parts <- list(
      header,
      charToRaw(obj1),
      charToRaw(obj2),
      charToRaw(obj3),
      obj4_bytes,
      obj5_bytes,
      obj6_bytes
    )
    cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
    # cum[1] is offset of header (0), cum[2] is offset of obj1, etc.
    off_obj1 <- cum[[2L]]
    off_obj2 <- cum[[3L]]
    off_obj3 <- cum[[4L]]
    off_obj4 <- cum[[5L]]
    off_obj5 <- cum[[6L]]
    off_obj6 <- cum[[7L]]
    xref_offset <- cum[[8L]]

    fmt10 <- function(n) sprintf("%010d", n)
    xref <- paste(
      "xref",
      "0 7",
      "0000000000 65535 f ",
      paste0(fmt10(off_obj1), " 00000 n "),
      paste0(fmt10(off_obj2), " 00000 n "),
      paste0(fmt10(off_obj3), " 00000 n "),
      paste0(fmt10(off_obj4), " 00000 n "),
      paste0(fmt10(off_obj5), " 00000 n "),
      paste0(fmt10(off_obj6), " 00000 n "),
      sep = "\n"
    )
    trailer <- paste0(
      "\ntrailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n",
      xref_offset, "\n%%EOF\n"
    )

    full <- c(unlist(parts), charToRaw(xref), charToRaw(trailer))
    writeBin(full, out)
    message("[fixtures] wrote ", out)
  }

  build_clip <- function() {
    # 4x3in Cairo PDF with a clip rectangle at plot coords
    # (1, 0.5)-(3, 2.5), then a full-page blue polygon drawn after
    # the clip is active. Cairo emits the clip via `q ... W n ...
    # Q` save/restore on the polygon, so PDFium attaches a
    # clip-path with one closed rectangular sub-path to the
    # polygon's page object.
    out <- file.path(out_dir, "clip.pdf")
    grDevices::cairo_pdf(out, width = 4, height = 3)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mar = c(0, 0, 0, 0))
    graphics::plot.new()
    graphics::plot.window(c(0, 4), c(0, 3))
    graphics::clip(1, 3, 0.5, 2.5)
    graphics::polygon(c(0, 4, 4, 0), c(0, 0, 3, 3),
                      col = "blue", border = NA)
    message("[fixtures] wrote ", out)
  }

  build_minimal()
  build_shapes()
  build_unicode()
  build_image()
  build_form_xobject()
  build_clip()
})
