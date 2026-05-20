# Tests for pdf_form_objects(). Uses form_xobject.pdf - a
# hand-built minimal PDF containing:
#
#   - Form 1 (populated): two stroked rectangles in form-local
#     coordinates - rect 1 at (0, 0)-(50, 50) with red stroke,
#     rect 2 at (60, 0)-(100, 60) with green stroke. Drawn on the
#     page at (50, 50) via matrix [1 0 0 1 50 50].
#
#   - Form 2 (empty): a no-op `q Q` stream with no nested objects.
#     Exercises the n == 0 short-circuit in pdf_form_objects().

# Helper: return the populated form (obj 1) plus its parent page so
# callers can defer-close both.
form_obj <- function(doc) {
  page <- pdf_load_page(doc, 1L)
  objs <- pdf_page_objects(page)
  forms <- Filter(function(o) identical(o$type, "form"), objs)
  if (length(forms) == 0L) {
    pdf_close_page(page)
    testthat::skip("form_xobject.pdf fixture has no form objects")
  }
  list(form = forms[[1L]], page = page)
}

test_that("form fixture exposes one populated and one empty form", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  expect_length(objs, 2L)
  expect_identical(
    vapply(objs, function(o) o$type, character(1)),
    c("form", "form")
  )
})

test_that("pdf_form_objects on an empty form returns an empty list", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  forms <- Filter(
    function(o) identical(o$type, "form"),
    pdf_page_objects(page)
  )
  skip_if(length(forms) < 2L, "fixture lacks an empty form")
  empty <- forms[[2L]]

  result <- pdf_form_objects(empty)
  expect_type(result, "list")
  expect_length(result, 0L)
})

test_that("pdf_form_objects returns the two nested rectangles", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)

  nested <- pdf_form_objects(bundle$form)
  expect_type(nested, "list")
  expect_length(nested, 2L)
  for (n in nested) expect_s3_class(n, "pdfium_obj")
  expect_identical(
    vapply(nested, function(o) o$type, character(1)),
    c("path", "path")
  )
  expect_identical(
    vapply(nested, function(o) o$index, integer(1)),
    c(1L, 2L)
  )
})

test_that("nested objects record parent_form and render with the chain", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)

  nested <- pdf_form_objects(bundle$form)
  expect_s3_class(nested[[1L]]$parent_form, "pdfium_obj")
  expect_identical(nested[[1L]]$parent_form$type, "form")
  expect_identical(nested[[1L]]$parent_form$index, bundle$form$index)
  # format() should walk the containment chain.
  fmt <- format(nested[[1L]])
  expect_match(fmt, "obj 1 of form 1 on page 1")
  expect_match(format(nested[[2L]]), "obj 2 of form")
})

test_that("nested objects participate in the general pdfium_obj API", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)

  nested <- pdf_form_objects(bundle$form)
  # First rect bounds in form coords are (0, 0)-(50, 50) with 2pt
  # stroke, so PDFium reports the stroked bbox slightly outset.
  b1 <- pdf_obj_bounds(nested[[1L]])
  expect_equal(b1[["left"]], -2, tolerance = 0.1)
  expect_equal(b1[["bottom"]], -2, tolerance = 0.1)
  expect_equal(b1[["right"]], 52, tolerance = 0.1)
  expect_equal(b1[["top"]], 52, tolerance = 0.1)
  # Path segment readout works on the nested object.
  segs <- pdf_path_segments(nested[[1L]])
  expect_s3_class(segs, "data.frame")
  expect_gt(nrow(segs), 0L)
})

test_that("the form's own matrix exposes its placement on the page", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)

  M <- pdf_obj_matrix(bundle$form)
  # The fixture's page content stream uses `1 0 0 1 50 50 cm` before
  # drawing the form: a pure translation by (50, 50). In 3x3
  # homogeneous form that's:
  #   | 1 0 50 |
  #   | 0 1 50 |
  #   | 0 0  1 |
  expected <- matrix(
    c(
      1, 0, 50,
      0, 1, 50,
      0, 0, 1
    ),
    nrow = 3, byrow = TRUE
  )
  expect_equal(M, expected)
})

test_that("pdf_form_objects rejects non-form objects", {
  # A path object from shapes.pdf is the simplest non-form to test
  # against.
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(
    function(o) identical(o$type, "path"),
    pdf_page_objects(page)
  )
  skip_if(length(paths) == 0L, "shapes.pdf has no path objects")
  expect_error(
    pdf_form_objects(paths[[1L]]),
    "Must be element of set"
  )
})

test_that("pdf_form_objects rejects bad inputs", {
  expect_error(
    pdf_form_objects("not-an-obj"),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_form_objects(list()),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_form_objects(42),
    "class .pdfium_obj."
  )
})

test_that("pdf_form_objects refuses a closed parent page", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  objs <- pdf_page_objects(page)
  forms <- Filter(function(o) identical(o$type, "form"), objs)
  skip_if(length(forms) == 0L, "no form objects")
  form <- forms[[1L]]
  pdf_close_page(page)

  expect_error(
    pdf_form_objects(form),
    "Parent page has been closed"
  )
})
