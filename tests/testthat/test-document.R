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
