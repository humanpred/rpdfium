# Tests for `summary()` methods on the six `pdfium_*_list` classes.
# Every one is a thin dispatcher to its companion `as_tibble.*`
# method; the test surface is therefore "does dispatch happen?" not
# "are the columns right?" — column-shape tests live in each list
# type's own test file.

test_that("summary(pdf_page_objects(...)) dispatches to as_tibble", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  expect_identical(summary(objs), tibble::as_tibble(objs))
})

test_that("summary(pdf_annotations(...)) dispatches to as_tibble", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  annots <- pdf_annotations(page)
  expect_identical(summary(annots), tibble::as_tibble(annots))
})

test_that("summary(pdf_attachments(...)) dispatches to as_tibble", {
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  atts <- pdf_attachments(doc)
  expect_identical(summary(atts), tibble::as_tibble(atts))
})

test_that("summary(pdf_signatures(...)) dispatches to as_tibble", {
  doc <- pdf_doc_open(fixture_path("signed"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  sigs <- pdf_signatures(doc)
  expect_identical(summary(sigs), tibble::as_tibble(sigs))
})

test_that("summary(pdf_doc_bookmarks(...)) dispatches to as_tibble", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bms <- pdf_doc_bookmarks(doc)
  expect_identical(summary(bms), tibble::as_tibble(bms))
})

test_that("summary(pdf_form_fields(...)) dispatches to as_tibble", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  fields <- pdf_form_fields(doc)
  expect_identical(summary(fields), tibble::as_tibble(fields))
})

test_that("summary() on every list class returns a tibble", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_s3_class(summary(pdf_page_objects(page)), "tbl_df")
  expect_s3_class(summary(pdf_annotations(page)), "tbl_df")
  expect_s3_class(summary(pdf_attachments(doc)), "tbl_df")
  expect_s3_class(summary(pdf_signatures(doc)), "tbl_df")
  expect_s3_class(summary(pdf_doc_bookmarks(doc)), "tbl_df")
  expect_s3_class(summary(pdf_form_fields(doc)), "tbl_df")
})
