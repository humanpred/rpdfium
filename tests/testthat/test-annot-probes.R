# Tests for the generic annotation dict probe, AP accessor,
# link->annot bridge, direct obj MCID, and focusable-subtypes
# accessors. These un-defer the v0.1.0 Tier 3 items that don't fit
# any existing module.

test_that("pdf_annot_dict_value finds the highlight's /Subj", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  # The highlight is annotation_index 2; it carries /Subj=(Important).
  out <- pdf_annot_dict_value(doc, 2L, "Subj", page_num = 1L)
  expect_named(out, c(
    "has_key", "value_type", "value_string",
    "value_number"
  ))
  expect_true(out$has_key)
  expect_equal(out$value_string, "Important")
})

test_that("pdf_annot_dict_value reports has_key=FALSE for missing keys", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  out <- pdf_annot_dict_value(doc, 1L, "NoSuchKey", page_num = 1L)
  expect_false(out$has_key)
  expect_true(is.na(out$value_type))
})

test_that("pdf_annot_dict_value validates inputs", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(
    pdf_annot_dict_value(doc, 0L, "Subj"),
    "Assertion on"
  )
  expect_error(
    pdf_annot_dict_value(doc, 1L, ""),
    "Assertion on"
  )
})

test_that("pdf_annot_appearance returns a string or empty", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  # No /AP on any of annotated.pdf's annots — empty string.
  expect_equal(pdf_annot_appearance(doc, 1L, page_num = 1L), "")
  expect_equal(pdf_annot_appearance(doc, 1L,
    mode = "rollover",
    page_num = 1L
  ), "")
})

test_that("pdf_link_annot_at_point returns the link's annotation_index", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  out <- pdf_link_annot_at_point(doc, 125, 160, page_num = 1L)
  expect_true(out$found)
  # Link is annotation_index 3 in annotated.pdf.
  expect_equal(out$annotation_index, 3L)
  expect_type(out$z_order, "integer")
})

test_that("pdf_link_annot_at_point returns found=FALSE when miss", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  out <- pdf_link_annot_at_point(doc, 5, 5, page_num = 1L)
  expect_false(out$found)
  expect_true(is.na(out$annotation_index))
})

test_that("pdf_link_annot_at_point validates x and y", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_link_annot_at_point(doc, NA, 10), "Assertion on")
  expect_error(pdf_link_annot_at_point(doc, 10, NA), "Assertion on")
  expect_error(
    pdf_link_annot_at_point(doc, "100", 10),
    "Assertion on"
  )
  expect_error(
    pdf_link_annot_at_point(doc, 10, c(1, 2)),
    "Assertion on"
  )
})

test_that("pdf_annot_appearance validates inputs", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_annot_appearance(doc, 0L), "Assertion on")
  expect_error(pdf_annot_appearance(doc, NA), "Assertion on")
  expect_error(
    pdf_annot_appearance(doc, 1L, mode = "bogus"),
    "should be one of"
  )
})

test_that("pdf_obj_marked_content_id returns NA for untagged content", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  for (obj in pdf_page_objects(page)) {
    expect_true(is.na(pdf_obj_marked_content_id(obj)))
  }
})

test_that("pdf_doc_focusable_subtypes includes widget", {
  out <- pdf_doc_focusable_subtypes(fixture_path("annotated"))
  expect_type(out, "character")
  expect_true("widget" %in% out)
})
