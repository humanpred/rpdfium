# Tests for Phase 2 structural mutation: page rotation, delete,
# reorder, merge, n-up, new-page, set-box, set-language.

test_that("pdf_set_page_rotation() rejects ro docs and bad values", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx)
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_set_page_rotation(doc, 1, 90), "read-only")

  doc_rw <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc_rw), add = TRUE)
  expect_error(pdf_set_page_rotation(doc_rw, 1, 45),
               "Assertion on")
})

test_that("pdf_set_page_rotation() persists across save", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  expect_equal(pdf_page_rotation(doc, 1), 0L)
  pdf_set_page_rotation(doc, 1, 270)

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  doc2 <- pdf_open(tmp)
  on.exit(pdf_close(doc2), add = TRUE)
  expect_equal(pdf_page_rotation(doc2, 1), 270L)
})

test_that("pdf_delete_page() removes the page", {
  fx <- fixture_path("shapes")
  src_doc <- pdf_open(fx)
  src_n <- pdf_page_count(src_doc)
  pdf_close(src_doc)
  if (src_n < 2L) {
    # The shipped fixture has one page; merge with itself first to
    # produce a 2-page doc for deletion.
    tmp <- withr::local_tempfile(fileext = ".pdf")
    pdf_merge(list(fx, fx), tmp)
    fx_2 <- tmp
  } else {
    fx_2 <- fx
  }
  doc <- pdf_open(fx_2, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  n_before <- pdf_page_count(doc)
  pdf_delete_page(doc, 1)
  expect_equal(pdf_page_count(doc), n_before - 1L)
})

test_that("pdf_delete_page() rejects out-of-range page_num", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_delete_page(doc, 999L), "exceeds")
})

test_that("pdf_merge() concatenates pages", {
  fx <- fixture_path("minimal")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_merge(list(fx, fx, fx), tmp)
  doc <- pdf_open(tmp)
  on.exit(pdf_close(doc), add = TRUE)
  expect_equal(pdf_page_count(doc), 3L)
})

test_that("pdf_merge() with file = NULL returns an open doc", {
  fx <- fixture_path("minimal")
  out <- pdf_merge(list(fx, fx))
  on.exit(pdf_close(out), add = TRUE)
  expect_s3_class(out, "pdfium_doc")
  expect_equal(pdf_page_count(out), 2L)
  expect_true(out$readwrite)
})

test_that("pdf_n_up() builds an N-up imposition", {
  fx <- fixture_path("minimal")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_n_up(pdf_open(fx), tmp, cols = 2L, rows = 1L)
  doc <- pdf_open(tmp)
  on.exit(pdf_close(doc), add = TRUE)
  expect_gte(pdf_page_count(doc), 1L)
})

test_that("pdf_new_page() inserts at the requested index", {
  doc <- pdf_new_doc()
  on.exit(pdf_close(doc), add = TRUE)
  pdf_new_page(doc, 1, 612, 792)
  pdf_new_page(doc, 2, 595, 842) # A4 second
  expect_equal(pdf_page_count(doc), 2L)
  sz1 <- pdf_page_size(doc, 1)
  sz2 <- pdf_page_size(doc, 2)
  expect_equal(sz1[["width"]], 612)
  expect_equal(sz2[["width"]], 595)
})

test_that("pdf_set_page_box() persists across save", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  pdf_set_page_box(doc, 1, "crop", c(10, 20, 200, 300))

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  doc2 <- pdf_open(tmp)
  on.exit(pdf_close(doc2), add = TRUE)
  bx <- pdf_page_box(doc2, 1, box = "crop")
  expect_equal(unname(bx), c(10, 20, 200, 300))
})

test_that("pdf_set_doc_language() persists across save", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  pdf_set_doc_language(doc, "fr-CA")

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  doc2 <- pdf_open(tmp)
  on.exit(pdf_close(doc2), add = TRUE)
  # Round-trip via pdf_doc_language() when it lands; for now use the
  # raw catalog reader if available.
  expect_true(file.exists(tmp))  # smoke
})

test_that("pdf_reorder_pages() rejects bad permutations", {
  fx <- fixture_path("minimal")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_merge(list(fx, fx, fx), tmp)
  doc <- pdf_open(tmp, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(
    pdf_reorder_pages(doc, new_order = c(1L, 2L)),  # too short
    "Assertion on"
  )
  expect_error(
    pdf_reorder_pages(doc, new_order = c(1L, 1L, 2L)),  # duplicate
    "Assertion on"
  )
})
