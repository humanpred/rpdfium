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
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  forms <- Filter(function(o) identical(o$type, "form"), objs)
  if (length(forms) == 0L) {
    pdf_page_close(page)
    testthat::skip("form_xobject.pdf fixture has no form objects")
  }
  list(form = forms[[1L]], page = page)
}

test_that("form fixture exposes one populated and one empty form", {
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  expect_length(objs, 2L)
  expect_identical(
    vapply(objs, function(o) o$type, character(1)),
    c("form", "form")
  )
})

test_that("pdf_form_objects on an empty form returns an empty list", {
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
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
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- form_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  forms <- Filter(function(o) identical(o$type, "form"), objs)
  skip_if(length(forms) == 0L, "no form objects")
  form <- forms[[1L]]
  pdf_page_close(page)

  expect_error(
    pdf_form_objects(form),
    "Parent page has been closed"
  )
})

test_that("cpp_form_get_object rejects an out-of-range index", {
  # Direct cpp::: call: the R-side iterates 0..n-1 from the count, so
  # this shim's bad-index stop is unreachable through the wrapper.
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  forms <- Filter(
    function(o) identical(o$type, "form"),
    pdf_page_objects(page)
  )
  skip_if(length(forms) == 0L, "no form objects")
  expect_error(
    pdfium:::cpp_form_get_object(forms[[1L]]$ptr, 999L),
    "returned NULL"
  )
})

test_that("objects of a form in an annotation follow the annotation", {
  doc <- pdf_doc_open(source = inline_annot_objects_pdf(), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  a <- pdf_annotations(page)[[1L]]
  form <- pdf_annot_objects(a)[[5L]]
  child <- pdf_form_objects(form)[[1L]]
  expect_identical(pdf_text_font_size(child), 10)
  # The annotation owns the form and its children, so clearing the
  # annotation's handle refuses the child as it does the form, before
  # anything reaches into memory the annotation may have freed.
  pdf_annot_delete(a)
  deleted <- paste0(
    "^Parent annotation has been closed: it was deleted with ",
    "pdf_annot_delete\\(\\)\\. The object handle is no longer valid\\.$"
  )
  expect_false(is_open(form))
  expect_false(is_open(child))
  expect_identical(
    format(child), "<pdfium_obj [closed] text, obj 1 of form 5 on page 1>"
  )
  expect_error(pdf_obj_bounds(form), deleted)
  expect_error(pdf_form_objects(form), deleted)
  expect_error(pdf_text_font_size(child), deleted)
  expect_error(pdf_text_content(child), deleted)
  for (ptr in list(form$ptr, child$ptr)) {
    expect_error(
      pdfium:::cpp_obj_bounds(ptr),
      "^Page-object handle's parent has been closed"
    )
  }
})

# Nested objects close with their form (ADR-029) ---------------------
#
# The objects pdf_form_objects() returns pin the form handle they were
# read through, so they are refused once that handle is closed, even
# when the form still exists elsewhere, as after a move.

form_closed_obj_msg <- paste0(
  "^Parent form object has been closed: it was deleted, removed from ",
  "its form or annotation, or moved into an annotation\\. The object ",
  "handle is no longer valid\\.$"
)

test_that("pdf_obj_delete() on a form closes the objects read from it", {
  doc <- pdf_doc_open(source = inline_annot_objects_pdf(), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  form <- pdf_page_objects(page)[[1L]]
  child <- pdf_form_objects(form)[[1L]]
  expect_identical(pdf_text_font_size(child), 10)
  pdf_obj_delete(form)
  expect_false(is_open(child))
  expect_identical(
    format(child), "<pdfium_obj [closed] text, obj 1 of form 1 on page 1>"
  )
  expect_error(pdf_text_font_size(child), form_closed_obj_msg)
  expect_error(pdf_obj_bounds(child), form_closed_obj_msg)
  expect_error(
    pdfium:::cpp_text_font_size(child$ptr),
    "^Page-object handle's parent has been closed"
  )
})

test_that("objects read from a form moved into an annotation are re-read", {
  doc <- pdf_doc_open(source = inline_annot_objects_pdf(), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  form <- pdf_page_objects(page)[[1L]]
  child <- pdf_form_objects(form)[[1L]]
  a <- pdf_annot_new(page, "stamp", bounds = c(0, 0, 100, 100))
  pdf_annot_append_object(a, form)
  # The move closes the form's handle, and with it the objects read
  # through it, although the form and its objects still exist.
  expect_false(is_open(child))
  expect_error(pdf_text_font_size(child), form_closed_obj_msg)
  # Read again through the annotation, they are usable until it is
  # deleted.
  moved <- pdf_form_objects(pdf_annot_objects(a)[[1L]])[[1L]]
  expect_identical(pdf_text_font_size(moved), 10)
  pdf_annot_delete(a)
  expect_false(is_open(moved))
  expect_error(
    pdf_text_font_size(moved),
    paste0(
      "^Parent annotation has been closed: it was deleted with ",
      "pdf_annot_delete\\(\\)\\. The object handle is no longer valid\\.$"
    )
  )
  expect_error(pdf_text_font_size(child), form_closed_obj_msg)
})

test_that("removing a nested form closes the objects read from it", {
  doc <- pdf_doc_open(source = inline_nested_forms_pdf(3L), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  outer <- pdf_page_objects(page)[[1L]]
  middle <- pdf_form_objects(outer)[[1L]]
  inner <- pdf_form_objects(middle)[[1L]]
  path <- pdf_form_objects(inner)[[1L]]
  expect_identical(path$type, "path")
  pdf_form_obj_remove_object(outer, middle)
  for (obj in list(inner, path)) {
    expect_false(is_open(obj))
    expect_error(pdf_obj_bounds(obj), form_closed_obj_msg)
  }
  expect_true(is_open(outer))
  expect_length(pdf_form_objects(outer), 0L)
})

test_that("the deepest objects PDFium parses follow their outermost form", {
  # PDFium parses Form XObjects nested 40 deep; deeper ones read as
  # empty. The chain from the innermost clip path up to the document is
  # then 44 externalptrs long, within validate_handle()'s cap.
  doc <- pdf_doc_open(source = inline_nested_forms_pdf(40L), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  outer <- pdf_page_objects(page)[[1L]]
  obj <- outer
  levels <- 0L
  while (identical(obj$type, "form")) {
    obj <- pdf_form_objects(obj)[[1L]]
    levels <- levels + 1L
  }
  expect_identical(levels, 40L)
  expect_identical(obj$type, "path")
  clip <- pdf_obj_clip_path(obj)
  expect_identical(pdfium:::cpp_clip_path_count_paths(clip$ptr), 1L)
  expect_identical(pdf_clip_path_count(clip), 1L)
  pdf_obj_delete(outer)
  expect_error(pdf_obj_bounds(obj), form_closed_obj_msg)
  expect_error(
    pdfium:::cpp_clip_path_count_paths(clip$ptr),
    "^Clip-path handle's parent has been closed"
  )
})
