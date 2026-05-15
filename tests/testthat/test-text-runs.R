# Tests for pdf_text_runs() - the batched text-run extractor.

test_that("pdf_text_runs returns the documented tibble shape", {
  res <- pdf_text_runs(pdf_open(fixture_path("shapes")))
  expect_s3_class(res, "tbl_df")
  expect_named(res, c("text_index", "bounds_left", "bounds_bottom",
                      "bounds_right", "bounds_top", "font_size", "text"))
  expect_type(res$text_index,  "integer")
  expect_type(res$bounds_left, "double")
  expect_type(res$font_size,   "double")
  expect_type(res$text,        "character")
})

test_that("pdf_text_runs returns one row per text object on shapes.pdf", {
  res <- pdf_text_runs(pdf_open(fixture_path("shapes")))
  expect_equal(nrow(res), 1L)
  expect_identical(res$text[[1]], "Hello")
  # The Cairo-built shapes fixture puts "Hello" as the 5th page
  # object (after the page-bounds path and three user paths).
  expect_identical(res$text_index[[1]], 5L)
  expect_true(res$bounds_right[[1]] > res$bounds_left[[1]])
  expect_true(res$bounds_top[[1]]   > res$bounds_bottom[[1]])
})

test_that("pdf_text_runs enumerates every text object on a multi-text page", {
  res <- pdf_text_runs(pdf_open(fixture_path("unicode")))
  # Cairo's ligature handling splits "pdfium" into three runs around
  # its "fi" ligature glyph, plus the two whole-word lines:
  expect_equal(nrow(res), 5L)
  expect_identical(res$text, c("Hello", "world", "pd", "fi", "um"))
  expect_true(all(res$bounds_right > res$bounds_left))
  expect_true(all(res$bounds_top   > res$bounds_bottom))
  expect_true(all(res$font_size > 0))
})

test_that("pdf_text_runs accepts a pdfium_page (caller still owns it)", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  res <- pdf_text_runs(page)
  expect_equal(nrow(res), 1L)
  expect_true(is_open(page))  # not closed by the helper
})

test_that("pdf_text_runs validates inputs and refuses closed pages", {
  expect_error(pdf_text_runs("nope"),
               "must be a `pdfium_page` or `pdfium_doc`")

  doc <- pdf_open(fixture_path("shapes"))
  on.exit(try(pdf_close(doc), silent = TRUE), add = TRUE)
  page <- pdf_load_page(doc, 1)
  pdf_close_page(page)
  expect_error(pdf_text_runs(page), "Page has been closed")
})

test_that("pdf_extract_paths' text_runs attribute matches pdf_text_runs()", {
  doc <- pdf_open(fixture_path("unicode"))
  on.exit(pdf_close(doc), add = TRUE)
  extracted <- pdf_extract_paths(doc, 1)
  direct <- pdf_text_runs(doc, 1)
  expect_identical(attr(extracted, "text_runs"), direct)
})
