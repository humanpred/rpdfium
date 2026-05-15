# Tests for the pdf_extract_paths() one-call helper.

test_that("pdf_extract_paths returns the documented tibble shape", {
  res <- pdf_extract_paths(fixture_path("shapes"))
  expect_s3_class(res, "tbl_df")

  expected_cols <- c(
    "path_index", "segment_index", "type", "x", "y", "close",
    "stroke_red", "stroke_green", "stroke_blue", "stroke_alpha",
    "stroke_width",
    "fill_red", "fill_green", "fill_blue", "fill_alpha",
    "bounds_left", "bounds_bottom", "bounds_right", "bounds_top"
  )
  expect_named(res, expected_cols)
  expect_type(res$path_index,    "integer")
  expect_type(res$segment_index, "integer")
  expect_type(res$type,          "character")
  expect_type(res$close,         "logical")
})

test_that("pdf_extract_paths attaches page_size_pt / rotation / text_runs", {
  res <- pdf_extract_paths(fixture_path("shapes"))

  ps <- attr(res, "page_size_pt")
  expect_type(ps, "double")
  expect_named(ps, c("width", "height"))
  expect_equal(ps[["width"]],  4 * 72, tolerance = 1e-3)
  expect_equal(ps[["height"]], 3 * 72, tolerance = 1e-3)

  expect_identical(attr(res, "page_rotation"), 0L)

  tr <- attr(res, "text_runs")
  expect_s3_class(tr, "tbl_df")
  expect_named(tr, c("text_index", "bounds_left", "bounds_bottom",
                     "bounds_right", "bounds_top", "font_size", "text"))
  expect_equal(nrow(tr), 1L)
  expect_equal(tr$text[[1]], "")  # Phase 3 will populate
  expect_gt(tr$font_size[[1]], 0)
})

test_that("rectangle path's rows carry the expected style + bbox", {
  res <- pdf_extract_paths(fixture_path("shapes"))

  # The user-drawn rectangle is path_index = 2 (after Cairo's page
  # bounds path at index 1).
  rect <- res[res$path_index == 2, ]
  expect_equal(nrow(rect), 5L)
  expect_identical(rect$type[[1]], "moveto")
  expect_true(all(rect$type[-1] == "lineto"))
  expect_true(rect$close[nrow(rect)])
  expect_false(any(rect$close[-nrow(rect)]))

  # Style: red border, lightblue fill (from build-fixtures.R).
  expect_true(all(rect$stroke_red   == 255))
  expect_true(all(rect$stroke_green == 0))
  expect_true(all(rect$stroke_blue  == 0))
  expect_true(all(rect$fill_red     == 173))
  expect_true(all(rect$fill_green   == 216))
  expect_true(all(rect$fill_blue    == 230))

  # Stroke width and bbox are constant across the path's rows.
  expect_equal(length(unique(rect$stroke_width)), 1L)
  expect_gt(rect$stroke_width[[1]], 0)
  for (col in c("bounds_left", "bounds_bottom",
                "bounds_right", "bounds_top")) {
    expect_equal(length(unique(rect[[col]])), 1L)
  }
})

test_that("pdf_extract_paths accepts an already-open pdfium_doc", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)

  res <- pdf_extract_paths(doc, page = 1)
  expect_gt(nrow(res), 0L)
  expect_true(is_open(doc))  # caller still owns the doc
})

test_that("pdf_extract_paths refuses a closed doc", {
  doc <- pdf_open(fixture_path("shapes"))
  pdf_close(doc)
  expect_error(pdf_extract_paths(doc), "Document has been closed")
})

test_that("pdf_extract_paths reports zero rows for a page with no paths", {
  # Skipped on this branch because the minimal fixture in fact has 1
  # Cairo page-bounds path. We test the empty-tibble shape directly.
  empty <- pdfium:::empty_paths_tibble()
  expect_s3_class(empty, "tbl_df")
  expect_equal(nrow(empty), 0L)
  expect_equal(ncol(empty), 19L)

  empty_tr <- pdfium:::empty_text_runs_tibble()
  expect_s3_class(empty_tr, "tbl_df")
  expect_equal(nrow(empty_tr), 0L)
  expect_equal(ncol(empty_tr), 7L)
})

test_that("text_runs row matches the 'Hello' text object on shapes.pdf", {
  res <- pdf_extract_paths(fixture_path("shapes"))
  tr <- attr(res, "text_runs")
  expect_equal(nrow(tr), 1L)
  expect_true(tr$bounds_right > tr$bounds_left)
  expect_true(tr$bounds_top   > tr$bounds_bottom)
  # The Cairo "Hello" text is em-size 1; the CTM does the visual
  # scaling. pdf_text_font_size docs explain this contract.
  expect_equal(tr$font_size, 1, tolerance = 1e-6)
})
