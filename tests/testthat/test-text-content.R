# Tests for pdf_text_content().

test_that("pdf_text_content extracts the 'Hello' text from shapes.pdf", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  got <- pdf_text_content(text_obj)
  expect_type(got, "character")
  expect_length(got, 1L)
  expect_identical(got, "Hello")
  # Sanity: no doubled-encoding, no leftover null bytes, no padding.
  expect_equal(nchar(got, type = "bytes"), 5L)
  expect_equal(nchar(got, type = "chars"), 5L)
  # The string is marked UTF-8 by Rf_mkCharLenCE, but R reports
  # Encoding() as "unknown" for pure-ASCII payloads where no
  # encoding ambiguity exists - that is R's optimization, not a
  # wrapper bug.
})

test_that("pdf_text_content handles a multi-text-object page (unicode.pdf)", {
  pdf <- fixture_path("unicode")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  texts <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  contents <- vapply(texts, pdf_text_content, character(1))

  # Cairo emits "pdfium" as three runs around its "fi" ligature glyph:
  # "pd", "fi", "um". PDFium's text extractor recovers the full word
  # by following the font's ToUnicode CMap on the ligature glyph.
  expect_identical(contents, c("Hello", "world", "pd", "fi", "um"))
})

test_that("pdf_text_content validates input and refuses non-text objects", {
  expect_error(pdf_text_content("nope"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  path_obj <- Filter(
    function(o) o$type == "path",
    pdf_page_objects(page)
  )[[1]]
  expect_error(
    pdf_text_content(path_obj),
    "Must be element of set"
  )
})

test_that("pdf_text_content refuses objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  pdf_close_page(page)
  expect_error(
    pdf_text_content(text_obj),
    "Parent page has been closed"
  )
})

test_that("pdf_extract_paths populates text_runs$text with the actual text", {
  res <- pdf_extract_paths(fixture_path("shapes"))
  tr <- attr(res, "text_runs")
  expect_equal(nrow(tr), 1L)
  expect_identical(tr$text[[1]], "Hello")
})

test_that("pdf_extract_paths text_runs round-trips multi-text-object pages", {
  res <- pdf_extract_paths(fixture_path("unicode"))
  tr <- attr(res, "text_runs")
  expect_equal(nrow(tr), 5L)
  expect_identical(tr$text, c("Hello", "world", "pd", "fi", "um"))
})
