# Tests for the Phase 7 form-filling API: pdf_form_field_set_value
# (polymorphic), pdf_form_field_clear, pdf_form_reset, and
# pdf_page_flatten. The shipped `annotated.pdf` fixture has one
# textfield ("name" = "Bob") and one checkbox ("agree" = Yes/on),
# which together cover the textfield + checkable code paths.

# Helper: open the annotated fixture readwrite, scoped to caller.
form_fill_open <- function(envir = parent.frame()) {
  # `fixture_path()` is in helper-fixtures.R; lintr can't see it
  # from this helper's body.
  doc <- pdf_doc_open(fixture_path("annotated"),  # nolint
                      readwrite = TRUE)
  withr::defer(pdf_doc_close(doc), envir = envir)
  fields <- pdf_form_fields(doc)
  types <- vapply(fields, pdf_form_field_type, character(1L))
  list(
    doc = doc,
    text = fields[types == "textfield"][[1L]],
    check = fields[types == "checkbox"][[1L]]
  )
}

# pdf_form_field_set_value — text fields ---------------------------

test_that("pdf_form_field_set_value writes a textfield's /V", {
  s <- form_fill_open()
  expect_identical(pdf_form_field_value(s$text), "Bob")
  ret <- pdf_form_field_set_value(s$text, "Updated")
  expect_identical(ret, s$doc)
  expect_identical(pdf_form_field_value(s$text), "Updated")
  expect_setequal(s$doc$state$dirty_pages, 1L)
})

test_that("pdf_form_field_set_value on textfield handles UTF-8", {
  s <- form_fill_open()
  msg <- enc2utf8("日本語テスト")
  pdf_form_field_set_value(s$text, msg)
  expect_identical(pdf_form_field_value(s$text), msg)
})

test_that("pdf_form_field_set_value rejects non-strings on text", {
  s <- form_fill_open()
  expect_error(pdf_form_field_set_value(s$text, 42L),
               "Assertion on")
  expect_error(pdf_form_field_set_value(s$text, NA_character_),
               "Assertion on")
})

# pdf_form_field_set_value — checkbox ------------------------------

test_that("pdf_form_field_set_value toggles a checkbox via logical", {
  s <- form_fill_open()
  expect_true(pdf_form_field_is_checked(s$check))
  pdf_form_field_set_value(s$check, FALSE)
  expect_false(pdf_form_field_is_checked(s$check))
  expect_identical(pdf_form_field_value(s$check), "Off")
  pdf_form_field_set_value(s$check, TRUE)
  expect_true(pdf_form_field_is_checked(s$check))
})

test_that("pdf_form_field_set_value accepts a literal /V string on checkbox", {
  s <- form_fill_open()
  # Same fixture: on-state name is "Yes"; passing it literally
  # should match the logical TRUE behaviour.
  pdf_form_field_set_value(s$check, "Yes")
  expect_true(pdf_form_field_is_checked(s$check))
  pdf_form_field_set_value(s$check, "Off")
  expect_false(pdf_form_field_is_checked(s$check))
})

test_that("pdf_form_field_set_value rejects bad checkbox inputs", {
  s <- form_fill_open()
  expect_error(pdf_form_field_set_value(s$check, NA),
               "Assertion on")
  expect_error(pdf_form_field_set_value(s$check, 1L),
               "Assertion on")
})

# pdf_form_field_set_value — invalid field types -------------------

test_that("pdf_form_field_set_value rejects fields without values", {
  # The annotated fixture has no signature / pushbutton fields, so
  # mock by spoofing the field_type_code to "signature" (7) on a
  # textfield handle. The dispatch should still error before any
  # /V write happens.
  s <- form_fill_open()
  bad <- s$text
  bad$field_type_code <- 7L  # signature
  expect_error(pdf_form_field_set_value(bad, "value"),
               "does not have a settable value")
})

# pdf_form_field_clear ---------------------------------------------

test_that("pdf_form_field_clear resets a textfield to empty", {
  s <- form_fill_open()
  pdf_form_field_set_value(s$text, "something")
  pdf_form_field_clear(s$text)
  # The fixture has no /DV, so the clear writes "".
  expect_identical(pdf_form_field_value(s$text), "")
})

test_that("pdf_form_field_clear unchecks a checkbox", {
  s <- form_fill_open()
  pdf_form_field_set_value(s$check, TRUE)
  pdf_form_field_clear(s$check)
  expect_false(pdf_form_field_is_checked(s$check))
})

# pdf_form_reset ---------------------------------------------------

test_that("pdf_form_reset clears every field", {
  s <- form_fill_open()
  pdf_form_field_set_value(s$text, "X")
  pdf_form_field_set_value(s$check, TRUE)
  ret <- pdf_form_reset(s$doc)
  expect_identical(ret, s$doc)
  # Re-fetch handles because pdf_form_reset's loop opens a fresh
  # field list internally; our original handles still work but
  # the canonical test is via a fresh read.
  fields <- pdf_form_fields(s$doc)
  type_names <- vapply(fields, pdf_form_field_type, character(1L))
  tf <- fields[type_names == "textfield"][[1L]]
  cb <- fields[type_names == "checkbox"][[1L]]
  expect_identical(pdf_form_field_value(tf), "")
  expect_false(pdf_form_field_is_checked(cb))
})

test_that("pdf_form_reset refuses a read-only doc", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_form_reset(doc), "readwrite")
})

# pdf_page_flatten -------------------------------------------------

test_that("pdf_page_flatten removes annotations from the page", {
  doc <- pdf_doc_open(fixture_path("annotated"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_gt(length(pdf_annotations(page)), 0L)
  ret <- pdf_page_flatten(page)
  expect_identical(ret, doc)
  expect_length(pdf_annotations(page), 0L)
  expect_setequal(doc$state$dirty_pages, 1L)
})

test_that("pdf_page_flatten accepts both modes", {
  doc <- pdf_doc_open(fixture_path("annotated"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  pdf_page_flatten(page, mode = "print")
  # No way to verify "which appearance baked", but the call should
  # succeed and remove annotations.
  expect_length(pdf_annotations(page), 0L)
})

test_that("pdf_page_flatten on an annot-free page is a no-op", {
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_silent(pdf_page_flatten(page))
})

test_that("pdf_page_flatten validates mode + readwrite", {
  doc <- pdf_doc_open(fixture_path("annotated"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(pdf_page_flatten(page, mode = "bogus"),
               "'arg' should be one of")

  doc_ro <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc_ro), add = TRUE)
  page_ro <- pdf_page_load(doc_ro, 1L)
  on.exit(pdf_page_close(page_ro), add = TRUE, after = FALSE)
  expect_error(pdf_page_flatten(page_ro), "readwrite")
})

# Closed-handle rejection ------------------------------------------

test_that("setters refuse a closed-page form field handle", {
  doc <- pdf_doc_open(fixture_path("annotated"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  fields <- pdf_form_fields(doc)
  tf <- fields[[1L]]
  pdf_page_close(tf$page)
  expect_error(pdf_form_field_set_value(tf, "x"),
               "has been closed")
  expect_error(pdf_form_field_clear(tf), "has been closed")
})

# Read-only doc rejection ------------------------------------------

test_that("setters refuse a read-only doc", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  fields <- pdf_form_fields(doc)
  tf <- fields[[1L]]
  expect_error(pdf_form_field_set_value(tf, "x"), "readwrite")
  expect_error(pdf_form_field_clear(tf), "readwrite")
})
