# Tests for pdf_image_new (JPEG embedding via
# FPDFImageObj_LoadJpegFileInline). Each test builds a fresh
# in-memory doc + page via pdf_doc_new() / pdf_page_new() and
# generates a JPEG with grDevices::jpeg() so the fixture cost is
# zero on every CI runner.

# Helper: fresh doc + page, scheduled to close in the caller.
img_blank_page <- function(envir = parent.frame()) {
  doc <- pdf_doc_new()
  withr::defer(pdf_doc_close(doc), envir = envir)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  withr::defer(pdf_page_close(page), envir = envir,
                priority = "first")
  list(doc = doc, page = page)
}

# Helper: tiny JPEG file in tempdir + a path that auto-cleans.
# Uses a 256×256 canvas with zero margins so the rect fills the
# whole image — smaller dimensions hit "figure margins too large"
# from the default plot.new() margins. par() settings here apply
# only to the JPEG device we open and discard, so no restore is
# needed (restoring after dev.off() would re-open a default
# device and leak a stray Rplots.pdf into the working directory).
make_test_jpeg <- function(envir = parent.frame(), width = 256L,
                            height = 256L) {
  path <- withr::local_tempfile(fileext = ".jpg", .local_envir = envir)
  grDevices::jpeg(path, width = width, height = height)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  graphics::rect(0, 0, 1, 1, col = "tomato", border = NA)
  path
}

# pdf_image_new (JPEG path) -----------------------------------------

test_that("pdf_image_new inserts an image obj from a JPEG file path", {
  s <- img_blank_page()
  jp <- make_test_jpeg()
  obj <- pdf_image_new(s$page, jp,
                        bounds = c(72, 600, 272, 700))
  expect_s3_class(obj, "pdfium_obj")
  expect_identical(obj$type, "image")
  expect_setequal(s$doc$state$dirty_pages, 1L)
  # The page now has exactly one object (the image).
  expect_equal(length(pdf_page_objects(s$page)), 1L)
})

test_that("pdf_image_new inserts an image obj from raw bytes", {
  s <- img_blank_page()
  jp <- make_test_jpeg()
  bytes <- readBin(jp, what = "raw", n = file.info(jp)$size)
  obj <- pdf_image_new(s$page, bytes,
                        bounds = c(72, 600, 272, 700))
  expect_identical(obj$type, "image")
})

test_that("pdf_image_new without bounds places at natural size", {
  s <- img_blank_page()
  jp <- make_test_jpeg(width = 32L, height = 32L)
  obj <- pdf_image_new(s$page, jp)
  expect_identical(obj$type, "image")
})

# Argument validation -----------------------------------------------

test_that("pdf_image_new rejects an unreadable path", {
  s <- img_blank_page()
  expect_error(pdf_image_new(s$page, tempfile(fileext = ".jpg")),
               "JPEG file not found")
})

test_that("pdf_image_new rejects unsupported `jpeg` types", {
  s <- img_blank_page()
  expect_error(pdf_image_new(s$page, 1L),
               "must be a raw vector")
  expect_error(pdf_image_new(s$page, list(raw(1L))),
               "must be a raw vector")
})

test_that("pdf_image_new validates `bounds` shape", {
  s <- img_blank_page()
  jp <- make_test_jpeg()
  expect_error(pdf_image_new(s$page, jp, bounds = c(1, 2, 3)),
               "Assertion on")
  expect_error(pdf_image_new(s$page, jp,
                              bounds = c(NA_real_, 0, 1, 1)),
               "Assertion on")
})

# Read-only / closed-page rejection ---------------------------------

test_that("pdf_image_new refuses a read-only doc", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  jp <- make_test_jpeg()
  expect_error(pdf_image_new(page, jp), "readwrite")
})

test_that("pdf_image_new refuses a closed page", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, 1L, 612, 792)
  pdf_page_close(page)
  jp <- make_test_jpeg()
  expect_error(pdf_image_new(page, jp), "Page has been closed")
})

# Round-trip: open the saved PDF and confirm one image object -------

test_that("pdf_image_new round-trips through pdf_save", {
  s <- img_blank_page()
  jp <- make_test_jpeg(width = 16L, height = 16L)
  pdf_image_new(s$page, jp, bounds = c(0, 0, 100, 100))
  out <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(s$doc, out)

  doc2 <- pdf_doc_open(out)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  page2 <- pdf_page_load(doc2, 1L)
  on.exit(pdf_page_close(page2), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page2)
  types <- vapply(objs, function(o) o$type, character(1L))
  expect_true("image" %in% types)
})
