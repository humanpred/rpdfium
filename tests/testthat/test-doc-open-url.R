# Tests for pdf_doc_open_url(). The network test paths are
# necessarily skipped on CRAN — they use the `file://` scheme
# against a shipped fixture, which exercises the same url() +
# readBin() code path as a real `https://` URL without needing
# network access.

test_that("pdf_doc_open_url opens a file:// URL", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open_url(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_s3_class(doc, "pdfium_doc")
  expect_identical(pdf_page_count(doc), 1L)
})

test_that("pdf_doc_open_url stores the URL as the doc path", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open_url(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(doc$path, url)
})

test_that("pdf_doc_open_url forwards password + readwrite flags", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open_url(url, password = NULL, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_true(doc$readwrite)
})

test_that("pdf_doc_open_url rejects non-URL strings", {
  expect_error(pdf_doc_open_url("not-a-url"),
               "must start with http://")
  expect_error(pdf_doc_open_url("/path/to/file.pdf"),
               "must start with http://")
  expect_error(pdf_doc_open_url(""), "Assertion on")
})

test_that("pdf_doc_open_url rejects bad input types", {
  expect_error(pdf_doc_open_url(42L), "Assertion on")
  expect_error(pdf_doc_open_url(NULL), "Assertion on")
  expect_error(pdf_doc_open_url(c("a", "b")), "Assertion on")
})

test_that("pdf_doc_open_url surfaces URL connection errors", {
  bad_url <- "file:///definitely-not-a-file-on-this-system.pdf"
  suppressWarnings(expect_error(pdf_doc_open_url(bad_url)))
})

test_that("pdf_doc_open_url accepts http(s) URLs structurally", {
  # We can't actually fetch http(s) without network access, but the
  # URL-shape validation should accept these prefixes and only fail
  # later at the network step. base::url() emits a warning then
  # errors on unreachable hosts; suppressWarnings so the test
  # output isn't noisy.
  suppressWarnings({
    expect_error(pdf_doc_open_url("https://example.invalid/x.pdf"))
    expect_error(pdf_doc_open_url("http://example.invalid/x.pdf"))
    # Neither error should be the URL-shape error.
    err1 <- tryCatch(
      pdf_doc_open_url("https://example.invalid/x.pdf"),
      error = function(e) conditionMessage(e)
    )
  })
  expect_false(grepl("must start with", err1))
})

test_that("pdf_doc_open_url round-trips through pdf_doc_summary", {
  url <- paste0("file://", fixture_path("annotated"))
  doc <- pdf_doc_open_url(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  s <- pdf_doc_summary(doc)
  expect_identical(s$path, url)
  expect_gt(s$form_field_count, 0L)  # annotated.pdf has form fields
})
