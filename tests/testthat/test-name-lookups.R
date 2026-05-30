# Tests for the name- / point-based lookup helpers:
# pdf_doc_named_dest_by_name(), pdf_doc_bookmark_find(), pdf_form_field_at_point().

test_that("pdf_doc_bookmark_find returns a pdfium_bookmark handle", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bm <- pdf_doc_bookmark_find(doc, "Chapter 1")
  expect_s3_class(bm, "pdfium_bookmark")
  expect_equal(bm$index, 1L)
  expect_equal(bm$parent_index, 0L)
  expect_equal(bm$level, 1L)
  expect_identical(pdf_bookmark_title(bm), "Chapter 1")
  bm2 <- pdf_doc_bookmark_find(doc, "Section 1.1")
  expect_equal(bm2$index, 2L)
  expect_equal(bm2$parent_index, 1L)
  expect_equal(bm2$level, 2L)
  expect_identical(pdf_bookmark_title(bm2), "Section 1.1")
  bm3 <- pdf_doc_bookmark_find(doc, "Section 1.2")
  expect_equal(bm3$index, 3L)
  expect_equal(bm3$parent_index, 1L)
  expect_equal(bm3$level, 2L)
  expect_null(pdf_doc_bookmark_find(doc, "Missing"))
})

test_that("pdf_doc_bookmark_find handle round-trips into bookmark list", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bm <- pdf_doc_bookmark_find(doc, "Chapter 1")
  back <- as_pdfium_bookmark_list(list(bm))
  expect_s3_class(back, "pdfium_bookmark_list")
  expect_length(back, 1L)
  expect_identical(back[[1L]]$ptr, bm$ptr)
})

test_that("pdf_doc_bookmark_find validates title input", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_doc_bookmark_find(doc, ""), "Assertion on")
  expect_error(pdf_doc_bookmark_find(doc, NA_character_), "Assertion on")
  expect_error(pdf_doc_bookmark_find(doc, c("a", "b")), "Assertion on")
  expect_error(pdf_doc_bookmark_find(doc, 42), "Assertion on")
})

test_that("pdf_doc_named_dest_by_name returns the right shape", {
  # outline.pdf has no /Dests dict so any name should return found=FALSE.
  out <- pdf_doc_named_dest_by_name(fixture_path("outline"), "nope")
  expect_named(out, c(
    "found", "page", "dest_view", "dest_x",
    "dest_y", "dest_zoom"
  ))
  expect_false(out$found)
  expect_true(is.na(out$page))
})

test_that("pdf_doc_named_dest_by_name validates `name`", {
  expect_error(
    pdf_doc_named_dest_by_name(fixture_path("shapes"), ""),
    "Assertion on"
  )
  expect_error(
    pdf_doc_named_dest_by_name(fixture_path("shapes"), NA_character_),
    "Assertion on"
  )
})

test_that("pdf_form_field_at_point detects the textfield at its centre", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # The textfield rect in annotated.pdf is [50 100 200 120] —
  # sample its centre.
  out <- pdf_form_field_at_point(doc, 125, 110, page_num = 1L)
  expect_named(out, c("field_type", "z_order"))
  expect_equal(out$field_type, "textfield")
  expect_type(out$z_order, "integer")
  expect_gte(out$z_order, 0L)
})

test_that("pdf_form_field_at_point returns NA when no field is near", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_form_field_at_point(doc, 5, 5, page_num = 1L)
  expect_true(is.na(out$field_type))
  expect_true(is.na(out$z_order))
})

test_that("pdf_form_field_at_point validates x and y", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_form_field_at_point(doc, NA, 10), "Assertion on")
  expect_error(pdf_form_field_at_point(doc, 10, NA), "Assertion on")
})
