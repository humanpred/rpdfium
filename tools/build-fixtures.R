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
# Phase 0 ships a single fixture: `minimal.pdf`, one blank page produced by
# the base R Cairo PDF device. Later phases will add path / text / image
# fixtures.

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

  build_minimal()
})
