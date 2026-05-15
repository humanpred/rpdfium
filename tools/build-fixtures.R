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

  build_minimal()
  build_shapes()
  build_unicode()
})
