# Tests for pdf_attachments() / pdf_attachment_data().
# attachments.pdf is a hand-built fixture with a single
# text/plain attachment "hello.txt" carrying the bytes
# "hello world\n" (12 bytes).

test_that("pdf_attachments returns 0 rows for a doc with no attachments", {
  res <- pdf_attachments(fixture_path("shapes"))
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c("attachment_index", "name", "mime_type", "size_bytes"))
})

test_that("pdf_attachments reports the documented attachment", {
  res <- pdf_attachments(fixture_path("attachments"))
  expect_equal(nrow(res), 1L)
  expect_identical(res$attachment_index, 1L)
  expect_identical(res$name, "hello.txt")
  expect_identical(res$mime_type, "text/plain")
  expect_identical(res$size_bytes, 12)
})

test_that("pdf_attachment_data returns the embedded bytes verbatim", {
  data <- pdf_attachment_data(fixture_path("attachments"), 1L)
  expect_type(data, "raw")
  expect_length(data, 12L)
  expect_identical(rawToChar(data), "hello world\n")
})

test_that("pdf_attachments accepts a path or an open doc", {
  by_path <- pdf_attachments(fixture_path("attachments"))
  doc <- pdf_open(fixture_path("attachments"))
  on.exit(pdf_close(doc), add = TRUE)
  by_doc <- pdf_attachments(doc)
  expect_identical(by_path, by_doc)
})

test_that("pdf_attachment_data accepts a path or an open doc", {
  by_path <- pdf_attachment_data(fixture_path("attachments"), 1L)
  doc <- pdf_open(fixture_path("attachments"))
  on.exit(pdf_close(doc), add = TRUE)
  by_doc <- pdf_attachment_data(doc, 1L)
  expect_identical(by_path, by_doc)
})

test_that("pdf_attachment_data validates attachment_index", {
  fx <- fixture_path("attachments")
  expect_error(pdf_attachment_data(fx, 0), "positive integer")
  expect_error(pdf_attachment_data(fx, -1), "positive integer")
  expect_error(pdf_attachment_data(fx, 1.5), "positive integer")
  expect_error(pdf_attachment_data(fx, NA_integer_), "positive integer")
  expect_error(pdf_attachment_data(fx, c(1, 2)), "positive integer")
})

test_that("pdf_attachments rejects bad inputs and closed docs", {
  expect_error(pdf_attachments(42), "must be a `pdfium_doc` or a path")
  doc <- pdf_open(fixture_path("attachments"))
  pdf_close(doc)
  expect_error(pdf_attachments(doc), "Document has been closed")
})
