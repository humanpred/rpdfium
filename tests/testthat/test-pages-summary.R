# Tests for pdf_pages_summary() — per-page sibling of
# pdf_doc_summary(). Returns one row per page with the cheap
# by-index metadata (size, rotation, label).

test_that("pdf_pages_summary returns one row per page", {
  s <- pdf_pages_summary(fixture_path("minimal"))
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 1L)  # minimal.pdf is 1 page
  expect_named(s, c("page_num", "width", "height", "rotation", "label"))
})

test_that("pdf_pages_summary column types are stable", {
  s <- pdf_pages_summary(fixture_path("minimal"))
  expect_type(s$page_num, "integer")
  expect_type(s$width, "double")
  expect_type(s$height, "double")
  expect_type(s$rotation, "integer")
  expect_type(s$label, "character")
})

test_that("pdf_pages_summary reports correct page_num sequence", {
  s <- pdf_pages_summary(fixture_path("outline"))
  expect_identical(s$page_num, seq_len(nrow(s)))
})

test_that("pdf_pages_summary reports sane dimensions", {
  s <- pdf_pages_summary(fixture_path("minimal"))
  expect_true(all(s$width > 0))
  expect_true(all(s$height > 0))
  expect_true(all(s$rotation %in% c(0L, 90L, 180L, 270L)))
})

test_that("pdf_pages_summary matches pdf_page_size + pdf_page_rotation", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  s <- pdf_pages_summary(doc)
  # Cross-check the first page against the per-page readers.
  page1 <- pdf_page_size(doc, 1L)
  expect_identical(s$width[[1L]], as.numeric(page1[["width"]]))
  expect_identical(s$height[[1L]], as.numeric(page1[["height"]]))
  expect_identical(s$rotation[[1L]],
                   as.integer(pdf_page_rotation(doc, 1L)))
})

test_that("pdf_pages_summary accepts a path or open doc", {
  by_path <- pdf_pages_summary(fixture_path("outline"))
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_pages_summary(doc)
  expect_identical(by_path, by_doc)
})

test_that("pdf_pages_summary handles multi-page documents", {
  s <- pdf_pages_summary(fixture_path("outline"))
  expect_gt(nrow(s), 1L)
  expect_true(all(s$width > 0))
})

test_that("pdf_pages_summary forwards the password argument", {
  s <- pdf_pages_summary(fixture_path("minimal"), password = NULL)
  expect_equal(nrow(s), 1L)
})

test_that("pdf_pages_summary rejects a closed doc", {
  doc <- pdf_doc_open(fixture_path("minimal"))
  pdf_doc_close(doc)
  expect_error(pdf_pages_summary(doc), "Document has been closed")
})

test_that("pdf_pages_summary rejects bad input", {
  expect_error(pdf_pages_summary(42L), "Assertion on")
  expect_error(pdf_pages_summary(NULL), "Assertion on")
})

test_that("pdf_pages_summary label column is NA when no page labels", {
  s <- pdf_pages_summary(fixture_path("minimal"))
  # minimal.pdf has no /PageLabels.
  expect_true(all(is.na(s$label)))
})

# Internal helper -----------------------------------------------------

test_that("empty_pages_summary returns a zero-row tibble with the right shape", {
  empty <- pdfium:::empty_pages_summary()
  expect_s3_class(empty, "tbl_df")
  expect_equal(nrow(empty), 0L)
  expect_named(empty, c("page_num", "width", "height", "rotation", "label"))
  expect_type(empty$page_num, "integer")
  expect_type(empty$width, "double")
  expect_type(empty$rotation, "integer")
  expect_type(empty$label, "character")
})
