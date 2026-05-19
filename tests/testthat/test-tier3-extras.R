# Tests for the v0.1.0 "tier 3" niche read-side helpers:
# pdf_text_obj_rendered_bitmap(), pdf_attachment_dict_value(),
# pdf_text_char_obj_index().

test_that("pdf_text_obj_rendered_bitmap returns a pdfium_bitmap", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
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
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  text <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  skip_if(length(text) == 0L || length(paths) == 0L,
          "fixture lacks text/path objects")
  expect_error(pdf_text_obj_rendered_bitmap(text[[1L]], scale = 0),
               "positive finite numeric")
  expect_error(pdf_text_obj_rendered_bitmap(text[[1L]], scale = NA_real_),
               "positive finite numeric")
  expect_error(pdf_text_obj_rendered_bitmap(paths[[1L]]),
               "must be one of \\{text\\}")
})

test_that("pdf_attachment_dict_value returns the right shape", {
  doc <- pdf_open(fixture_path("attachments"))
  on.exit(pdf_close(doc), add = TRUE)
  # A real key on the attachment dict; "Subtype" if present, "Size"
  # otherwise. The fixture's attachments don't carry a Subtype, so
  # we expect has_key = FALSE and value = NA.
  out <- pdf_attachment_dict_value(doc, 1L, "Subtype")
  expect_named(out, c("has_key", "value_type", "value"))
  expect_type(out$has_key,   "logical")
  expect_type(out$value_type, "integer")
  expect_type(out$value,     "character")
})

test_that("pdf_attachment_dict_value validates inputs", {
  doc <- pdf_open(fixture_path("attachments"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_attachment_dict_value(doc, 0L, "Subtype"),
               "positive integer")
  expect_error(pdf_attachment_dict_value(doc, 1L, ""),
               "non-empty character")
})

test_that("pdf_text_char_obj_index reverse-maps chars to text-obj indices", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  chars <- pdf_text_chars(page)
  visible <- chars[!chars$is_generated, ]
  skip_if(nrow(visible) == 0L, "shapes.pdf has no visible chars")
  # First visible char must live on a text page object.
  obj_index <- pdf_text_char_obj_index(page,
                                        visible$char_index[[1L]])
  expect_type(obj_index, "integer")
  expect_gte(obj_index, 1L)
  # That index should pick out a text-type page object.
  objs <- pdf_page_objects(page)
  expect_equal(objs[[obj_index]]$type, "text")
})

test_that("pdf_text_char_obj_index validates char_index", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_text_char_obj_index(doc, 0L), "positive integer")
  expect_error(pdf_text_char_obj_index(doc, NA), "positive integer")
})
