# Tests for the v0.1.0 "tier 3" niche read-side helpers:
# pdf_text_obj_rendered_bitmap(), pdf_attachment_dict_value(),
# pdf_text_char_obj_index().

test_that("pdf_text_obj_rendered_bitmap returns a pdfium_bitmap", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  text <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  skip_if(length(text) == 0L, "shapes.pdf has no text objects")
  bmp <- pdf_text_obj_rendered_bitmap(text[[1L]], scale = 1)
  expect_s3_class(bmp, "pdfium_bitmap")
  expect_true(length(dim(bmp)) == 2L && all(dim(bmp) > 0L))
  # Higher scale -> larger bitmap.
  bmp2 <- pdf_text_obj_rendered_bitmap(text[[1L]], scale = 2)
  expect_true(prod(dim(bmp2)) > prod(dim(bmp)))
})

test_that("pdf_text_obj_rendered_bitmap validates scale and obj type", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  text <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  skip_if(
    length(text) == 0L || length(paths) == 0L,
    "fixture lacks text/path objects"
  )
  expect_error(
    pdf_text_obj_rendered_bitmap(text[[1L]], scale = 0),
    "Assertion on"
  )
  expect_error(
    pdf_text_obj_rendered_bitmap(text[[1L]], scale = NA_real_),
    "Assertion on"
  )
  expect_error(
    pdf_text_obj_rendered_bitmap(paths[[1L]]),
    "Must be element of set"
  )
})

# pdf_attachment_dict_value moved to test-attachments.R (handle-based)
# when attachments switched to a list-of-handles reader in
# ADR-017 / Phase 2.5c.

test_that("pdf_text_char_obj_index reverse-maps chars to text-obj indices", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  chars <- pdf_text_chars(page)
  visible <- chars[!chars$is_generated, ]
  skip_if(nrow(visible) == 0L, "shapes.pdf has no visible chars")
  # First visible char must live on a text page object.
  obj_index <- pdf_text_char_obj_index(
    page,
    visible$char_index[[1L]]
  )
  expect_type(obj_index, "integer")
  expect_gte(obj_index, 1L)
  # That index should pick out a text-type page object.
  objs <- pdf_page_objects(page)
  expect_equal(objs[[obj_index]]$type, "text")
})

test_that("pdf_text_char_obj_index validates char_index", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_text_char_obj_index(doc, 0L), "Assertion on")
  expect_error(pdf_text_char_obj_index(doc, NA), "Assertion on")
})
