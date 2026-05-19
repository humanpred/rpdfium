test_that("pdf_load_page() validates its inputs", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  expect_error(pdf_load_page("not a doc"), "must be a `pdfium_doc`")
  expect_error(
    pdf_load_page(doc, page_num = 0),
    "must be a single positive integer"
  )
  expect_error(
    pdf_load_page(doc, page_num = -1),
    "must be a single positive integer"
  )
  expect_error(
    pdf_load_page(doc, page_num = 1.5),
    "must be a single positive integer"
  )
  expect_error(
    pdf_load_page(doc, page_num = c(1, 2)),
    "must be a single positive integer"
  )
  expect_error(
    pdf_load_page(doc, page_num = NA_integer_),
    "must be a single positive integer"
  )
  expect_error(
    pdf_load_page(doc, page_num = "1"),
    "must be a single positive integer"
  )
  expect_error(
    pdf_load_page(doc, page_num = 99L),
    "exceeds the document's page count"
  )
})

test_that("pdf_load_page() returns a working pdfium_page", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  expect_s3_class(page, "pdfium_page")
  expect_true(is_open(page))
  expect_equal(page$index, 1L)
})

test_that("pdf_load_page() refuses a closed document", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  pdf_close(doc)
  expect_error(pdf_load_page(doc, 1), "Document has been closed")
})

test_that("pdf_close_page() is idempotent and refuses non-pages", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  expect_invisible(pdf_close_page(page))
  expect_invisible(pdf_close_page(page))
  expect_false(is_open(page))

  expect_error(pdf_close_page("nope"), "must be a `pdfium_page`")
})

test_that("page format / print reflect open / closed and parent path", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(try(pdf_close(doc), silent = TRUE), add = TRUE)

  page <- pdf_load_page(doc, 1)
  expect_match(format(page), "open")
  expect_match(format(page), "page 1 of minimal.pdf")
  expect_output(print(page), "pdfium_page")

  pdf_close_page(page)
  expect_match(format(page), "closed")
})

test_that("pdf_page_size accepts a page or a doc, returns width/height", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  size_doc <- pdf_page_size(doc, 1)
  expect_named(size_doc, c("width", "height"))
  expect_true(size_doc[["width"]] > 0)
  expect_true(size_doc[["height"]] > 0)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  size_page <- pdf_page_size(page)
  expect_equal(size_doc, size_page, tolerance = 1e-6)

  # minimal.pdf was generated via cairo_pdf(width = 4, height = 3) which
  # produces a page of 4 x 3 inches = 288 x 216 points.
  expect_equal(size_page[["width"]], 4 * 72, tolerance = 1e-3)
  expect_equal(size_page[["height"]], 3 * 72, tolerance = 1e-3)
})

test_that("pdf_page_size refuses closed handles and bad inputs", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(try(pdf_close(doc), silent = TRUE), add = TRUE)

  page <- pdf_load_page(doc, 1)
  pdf_close_page(page)
  expect_error(pdf_page_size(page), "Page has been closed")
  expect_error(pdf_page_size(42), "must be a `pdfium_page` or `pdfium_doc`")

  doc2 <- pdf_open(pdf)
  pdf_close(doc2)
  expect_error(pdf_page_size(doc2, 1L),
               "Document has been closed")
})

test_that("pdf_page_rotation returns 0/90/180/270 from a page or a doc", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  # The Cairo-built fixture is un-rotated.
  expect_identical(pdf_page_rotation(doc, 1), 0L)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  rot <- pdf_page_rotation(page)
  expect_identical(rot, 0L)
  expect_true(rot %in% c(0L, 90L, 180L, 270L))
})

test_that("pdf_page_rotation refuses closed handles and bad inputs", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(try(pdf_close(doc), silent = TRUE), add = TRUE)

  page <- pdf_load_page(doc, 1)
  pdf_close_page(page)
  expect_error(pdf_page_rotation(page), "Page has been closed")
  expect_error(pdf_page_rotation(42), "must be a `pdfium_page` or `pdfium_doc`")
})

test_that("auto-finalizer releases pages dropped without explicit close", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  load_and_drop <- function() {
    p <- pdf_load_page(doc, 1)
    invisible(cpp_page_size(p$ptr))
  }
  for (i in seq_len(50)) load_and_drop()
  invisible(gc(verbose = FALSE))
  succeed()
})

test_that("page outlives parent doc when doc reference is dropped", {
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  page <- pdf_load_page(doc, 1)
  rm(doc)
  invisible(gc(verbose = FALSE))
  # The doc handle is referenced by page via externalptr prot slot, so
  # FPDF_CloseDocument has not run. cpp_page_size should still work.
  size <- cpp_page_size(page$ptr)
  expect_true(size[["width"]] > 0)
  pdf_close_page(page)
})
