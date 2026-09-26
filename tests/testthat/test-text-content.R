# Tests for pdf_text_content().

test_that("pdf_text_content extracts the 'Hello' text from shapes.pdf", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  pdf_page_close(page)
  expect_error(
    pdf_text_content(text_obj),
    "Parent page has been closed"
  )
})

test_that("pdf_text_content refuses text in an annotation's appearance", {
  doc <- pdf_doc_open(source = inline_annot_objects_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  # The page draws the same Form XObject as the annotation, and its
  # text is read there.
  page_form <- pdf_page_objects(page)[[1L]]
  expect_identical(pdf_text_content(pdf_form_objects(page_form)[[1L]]),
                   "Nested")

  objs <- pdf_annot_objects(pdf_annotations(page)[[1L]])
  msg <- paste("`obj` is in an annotation's appearance stream; PDFium",
               "only reads the text of objects in the page's own content.")
  expect_error(pdf_text_content(objs[[2L]]), msg, fixed = TRUE)
  expect_error(pdf_text_content(pdf_form_objects(objs[[5L]])[[1L]]), msg,
               fixed = TRUE)
  # PDFium looks the object up in the page's text layer, which holds no
  # annotation content, so the shim finds no text for it.
  expect_identical(pdfium:::cpp_text_content(objs[[2L]]$ptr, page$ptr), "")
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
