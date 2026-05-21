test_that("pdf_doc_open() rejects bad inputs before touching PDFium", {
  expect_error(
    pdf_doc_open(NULL),
    "One of `path` or `source` must be provided"
  )
  expect_error(pdf_doc_open(character()), "Assertion on")
  expect_error(pdf_doc_open(NA_character_), "Assertion on")
  expect_error(pdf_doc_open(""), "Assertion on")
  expect_error(pdf_doc_open("/no/such/file.pdf"), "PDF file not found")
})

test_that("pdf_doc_open() validates the password argument", {
  pdf <- fixture_path("minimal")
  expect_error(pdf_doc_open(pdf, password = 1), "Assertion on")
  expect_error(pdf_doc_open(pdf, password = NA_character_), "Assertion on")
  expect_error(pdf_doc_open(pdf, password = c("a", "b")), "Assertion on")
  doc <- pdf_doc_open(pdf, password = NULL)
  expect_s3_class(doc, "pdfium_doc")
  pdf_doc_close(doc)
})

test_that("pdf_page_count() can take a path or an open doc", {
  pdf <- fixture_path("minimal")
  expect_equal(pdf_page_count(pdf), 1L)

  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_s3_class(doc, "pdfium_doc")
  expect_equal(pdf_page_count(doc), 1L)
})

test_that("pdf_doc_close() is idempotent and blocks further work", {
  pdf <- fixture_path("minimal")
  doc <- pdf_doc_open(pdf)
  expect_invisible(pdf_doc_close(doc))
  expect_invisible(pdf_doc_close(doc))
  expect_error(pdf_page_count(doc), "closed")
})

test_that("pdf_doc_close() refuses non-doc inputs", {
  expect_error(
    pdf_doc_close("not a doc"),
    "class .pdfium_doc."
  )
  expect_error(
    pdf_doc_close(NULL),
    "class .pdfium_doc."
  )
})

test_that("pdf_page_count() rejects non-doc inputs cleanly", {
  expect_error(
    pdf_page_count(42),
    "class .pdfium_doc."
  )
})

test_that("print() and format() reflect open / closed state", {
  pdf <- fixture_path("minimal")
  doc <- pdf_doc_open(pdf)
  on.exit(try(pdf_doc_close(doc), silent = TRUE), add = TRUE)
  expect_match(format(doc), "open")
  pdf_doc_close(doc)
  expect_match(format(doc), "closed")
  expect_output(print(doc), "closed")
})

test_that("auto-finalizer releases handles dropped without explicit close", {
  pdf <- fixture_path("minimal")
  open_and_drop <- function() {
    d <- pdf_doc_open(pdf)
    invisible(pdf_page_count(d))
  }
  for (i in seq_len(100)) {
    open_and_drop()
  }
  invisible(gc(verbose = FALSE))
  succeed()
})

# URL paths --------------------------------------------------------
# The `path =` argument auto-detects URLs (anything matching the RFC
# 3986 scheme://host shape) and routes them through base::url() +
# readBin() before handing the bytes to PDFium's in-memory loader.
# We don't maintain a scheme allowlist — whatever R's url() handles
# is what we handle.

test_that("pdf_doc_open accepts a file:// URL", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_s3_class(doc, "pdfium_doc")
  expect_identical(pdf_page_count(doc), 1L)
})

test_that("pdf_doc_open stores the URL as the doc path", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(doc$path, url)
})

test_that("pdf_doc_open passes URL bytes through to readwrite mode", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open(url, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_true(doc$readwrite)
})

test_that("pdf_doc_open surfaces base::url() errors on unreachable hosts", {
  # base::url() emits a warning then errors when the host is
  # unreachable; we suppress the warning to keep the test output
  # clean but assert the error still propagates.
  suppressWarnings(
    expect_error(pdf_doc_open("https://example.invalid/x.pdf"))
  )
})

test_that("pdf_doc_open treats non-URL strings as local paths", {
  # A string with a colon but no `://` is a path on this system,
  # not a URL — should not trigger url() handling.
  expect_error(pdf_doc_open("foo:bar"), "PDF file not found")
})

test_that("looks_like_url accepts every RFC 3986 scheme shape", {
  for (u in c("http://x", "https://x", "ftp://x", "file:///x",
              "FILE:///x", "git+ssh://x")) {
    expect_true(pdfium:::looks_like_url(u), info = u)
  }
  for (nu in c("/absolute/path", "relative/path", "x.pdf",
               "1http://no", NA_character_, c("a", "b"), 42L, NULL)) {
    expect_false(pdfium:::looks_like_url(nu),
                 info = deparse(nu, control = NULL))
  }
})

test_that("pdf_doc_open's URL path round-trips through pdf_doc_summary", {
  url <- paste0("file://", fixture_path("annotated"))
  doc <- pdf_doc_open(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  s <- pdf_doc_summary(doc)
  expect_identical(s$path, url)
  expect_gt(s$form_field_count, 0L)
})
