test_that("pdf_open() rejects bad inputs before touching PDFium", {
  expect_error(pdf_open(NULL),       "single, non-NA character")
  expect_error(pdf_open(character()),"single, non-NA character")
  expect_error(pdf_open(NA_character_), "single, non-NA character")
  expect_error(pdf_open(""),         "must not be the empty string")
  expect_error(pdf_open("/no/such/file.pdf"), "PDF file not found")
})

test_that("pdf_open() validates the password argument", {
  pdf <- fixture_path("minimal")
  expect_error(pdf_open(pdf, password = 1),         "must be NULL or a single")
  expect_error(pdf_open(pdf, password = NA_character_), "must be NULL or a single")
  expect_error(pdf_open(pdf, password = c("a","b")), "must be NULL or a single")
  doc <- pdf_open(pdf, password = NULL)
  expect_s3_class(doc, "pdfium_doc")
  pdf_close(doc)
})

test_that("pdf_page_count() can take a path or an open doc", {
  pdf <- fixture_path("minimal")
  expect_equal(pdf_page_count(pdf), 1L)

  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)
  expect_s3_class(doc, "pdfium_doc")
  expect_equal(pdf_page_count(doc), 1L)
})

test_that("pdf_close() is idempotent and blocks further work", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  expect_invisible(pdf_close(doc))
  expect_invisible(pdf_close(doc))
  expect_error(pdf_page_count(doc), "closed")
})

test_that("pdf_close() refuses non-doc inputs", {
  expect_error(pdf_close("not a doc"),
               "must be a `pdfium_doc`")
  expect_error(pdf_close(NULL),
               "must be a `pdfium_doc`")
})

test_that("pdf_page_count() rejects non-doc inputs cleanly", {
  expect_error(pdf_page_count(42),
               "must be a `pdfium_doc` or a path")
})

test_that("print() and format() reflect open / closed state", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(try(pdf_close(doc), silent = TRUE), add = TRUE)
  expect_match(format(doc), "open")
  pdf_close(doc)
  expect_match(format(doc), "closed")
  expect_output(print(doc), "closed")
})

test_that("auto-finalizer releases handles dropped without explicit close", {
  pdf <- fixture_path("minimal")
  for (i in seq_len(100)) {
    local({ d <- pdf_open(pdf); invisible(pdf_page_count(d)) })
  }
  invisible(gc(verbose = FALSE))
  succeed()
})
