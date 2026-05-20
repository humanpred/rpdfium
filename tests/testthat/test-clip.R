# Tests for pdf_obj_clip_path() + pdf_clip_path_count() +
# pdf_clip_path_segments(). Uses clip.pdf - a 4x3in Cairo PDF that
# sets a clip rectangle at plot coords (1, 0.5)-(3, 2.5) and then
# draws a full-page blue polygon. Cairo emits the clip via
# `q ... W n ... Q` save/restore around the polygon, so PDFium
# attaches a single closed rectangular sub-path to the polygon's
# page object. The clip's coordinates in PDF user-space points
# work out to roughly (77.3, 41.3)-(210.7, 174.7) per the smoke
# probe; the tests assert ranges rather than exact floats to ride
# out Cairo's internal rounding.

# Helper: load page 1 of clip.pdf and return (page, clipped_obj)
# where clipped_obj is the first page object whose pdf_obj_clip_path()
# is non-NULL.
clip_bundle <- function(doc) {
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  clipped <- Filter(function(o) !is.null(pdf_obj_clip_path(o)), objs)
  if (length(clipped) == 0L) {
    pdf_page_close(page)
    testthat::skip("clip.pdf fixture has no clipped objects")
  }
  list(page = page, obj = clipped[[1L]])
}

test_that("pdf_obj_clip_path returns NULL for objects with no clip", {
  doc <- pdf_doc_open(fixture_path("clip"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  no_clip <- Filter(function(o) is.null(pdf_obj_clip_path(o)), objs)
  expect_gt(length(no_clip), 0L)
})

test_that("pdf_obj_clip_path returns a pdfium_clip_path for clipped objects", {
  doc <- pdf_doc_open(fixture_path("clip"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  b <- clip_bundle(doc)
  on.exit(pdf_page_close(b$page), add = TRUE, after = FALSE)

  cp <- pdf_obj_clip_path(b$obj)
  expect_s3_class(cp, c("pdfium_clip_path", "pdfium_handle"), exact = TRUE)
  expect_identical(cp$source_obj_index, b$obj$index)
  expect_identical(cp$n_paths, 1L)
  expect_match(format(cp), "1 sub-path")
  expect_match(format(cp), "open")
})

test_that("pdf_clip_path_count returns the sub-path count", {
  doc <- pdf_doc_open(fixture_path("clip"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  b <- clip_bundle(doc)
  on.exit(pdf_page_close(b$page), add = TRUE, after = FALSE)

  cp <- pdf_obj_clip_path(b$obj)
  expect_identical(pdf_clip_path_count(cp), 1L)
})

test_that("pdf_clip_path_segments returns the rectangular clip geometry", {
  doc <- pdf_doc_open(fixture_path("clip"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  b <- clip_bundle(doc)
  on.exit(pdf_page_close(b$page), add = TRUE, after = FALSE)

  cp <- pdf_obj_clip_path(b$obj)
  segs <- pdf_clip_path_segments(cp)
  expect_s3_class(segs, "tbl_df")
  expect_named(segs, c(
    "path_index", "segment_index", "segment_type",
    "x", "y", "close_figure"
  ))
  expect_identical(nrow(segs), 5L)
  # All five segments belong to the single sub-path.
  expect_identical(unique(segs$path_index), 1L)
  expect_identical(segs$segment_index, 1L:5L)
  # First is a moveto, the rest are linetos, the final closes the
  # figure.
  expect_identical(segs$segment_type[[1L]], "moveto")
  expect_setequal(segs$segment_type[2L:5L], "lineto")
  expect_identical(segs$close_figure[[5L]], TRUE)
  # Geometry: the clip is a rectangle at plot (1, 0.5)-(3, 2.5);
  # at 72 dpi that maps to roughly (72-216, 36-180) PDF points.
  # Cairo rounds slightly, so allow ~2 pt slack.
  expect_equal(range(segs$x), c(72, 216), tolerance = 4)
  expect_equal(range(segs$y), c(36, 180), tolerance = 4)
})

test_that("pdf_obj_clip_path rejects bad input", {
  expect_error(
    pdf_obj_clip_path("not-an-obj"),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_obj_clip_path(list()),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_obj_clip_path(42),
    "class .pdfium_obj."
  )
})

test_that("pdf_clip_path_count + segments reject bad input", {
  expect_error(
    pdf_clip_path_count("not-a-clip"),
    "class .pdfium_clip_path."
  )
  expect_error(
    pdf_clip_path_count(list()),
    "class .pdfium_clip_path."
  )
  expect_error(
    pdf_clip_path_segments("not-a-clip"),
    "class .pdfium_clip_path."
  )
  expect_error(
    pdf_clip_path_segments(42),
    "class .pdfium_clip_path."
  )
})

test_that("clip-path accessors refuse a closed parent page", {
  doc <- pdf_doc_open(fixture_path("clip"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  clipped <- Filter(function(o) !is.null(pdf_obj_clip_path(o)), objs)
  skip_if(length(clipped) == 0L, "no clipped objects")
  obj <- clipped[[1L]]
  cp <- pdf_obj_clip_path(obj)
  pdf_page_close(page)

  expect_error(
    pdf_obj_clip_path(obj),
    "Parent page has been closed"
  )
  expect_error(
    pdf_clip_path_count(cp),
    "Parent page has been closed"
  )
  expect_error(
    pdf_clip_path_segments(cp),
    "Parent page has been closed"
  )
})

test_that("print.pdfium_clip_path emits a one-line description", {
  doc <- pdf_doc_open(fixture_path("clip"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  b <- clip_bundle(doc)
  on.exit(pdf_page_close(b$page), add = TRUE, after = FALSE)

  cp <- pdf_obj_clip_path(b$obj)
  expect_output(print(cp), "pdfium_clip_path")
})
