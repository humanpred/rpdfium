# Tests for pdf_form_fields(). annotated.pdf carries one
# AcroForm text field:
#   /T="name" /TU="Full name" /V="Bob" /FT=/Tx
# on page 1, in the rectangle [50 100 200 120].

test_that("pdf_form_fields returns 0 rows when the doc has no AcroForm", {
  res <- pdf_form_fields(fixture_path("shapes"))
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c("field_index", "page_num", "field_type",
                      "field_flags", "name", "alternate_name",
                      "value", "bounds_left", "bounds_bottom",
                      "bounds_right", "bounds_top", "options"))
})

test_that("pdf_form_fields reports the one documented text field", {
  res <- pdf_form_fields(fixture_path("annotated"))
  expect_equal(nrow(res), 1L)
  expect_identical(res$field_index,    1L)
  expect_identical(res$page_num,       1L)
  expect_identical(res$field_type,     "textfield")
  expect_identical(res$name,           "name")
  expect_identical(res$alternate_name, "Full name")
  expect_identical(res$value,          "Bob")
  expect_equal(res$bounds_left[[1L]],   50)
  expect_equal(res$bounds_bottom[[1L]], 100)
  expect_equal(res$bounds_right[[1L]],  200)
  expect_equal(res$bounds_top[[1L]],    120)
})

test_that("pdf_form_fields options column is a list of empty char vecs for non-choice fields", {
  res <- pdf_form_fields(fixture_path("annotated"))
  expect_type(res$options, "list")
  expect_length(res$options[[1L]], 0L)
})

test_that("pdf_form_fields accepts a path or an open doc", {
  by_path <- pdf_form_fields(fixture_path("annotated"))
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  by_doc <- pdf_form_fields(doc)
  expect_identical(by_path, by_doc)
})

test_that("pdf_form_fields rejects bad inputs and closed docs", {
  expect_error(pdf_form_fields(42), "must be a `pdfium_doc` or a path")
  doc <- pdf_open(fixture_path("annotated"))
  pdf_close(doc)
  expect_error(pdf_form_fields(doc), "Document has been closed")
})

test_that("form_field_type_name maps codes to documented strings", {
  expect_identical(
    pdfium:::form_field_type_name(0L:7L),
    c("unknown", "pushbutton", "checkbox", "radiobutton",
      "combobox", "listbox", "textfield", "signature")
  )
  expect_identical(pdfium:::form_field_type_name(99L), "unknown")
  expect_identical(pdfium:::form_field_type_name(-1L), "unknown")
  expect_identical(pdfium:::form_field_type_name(NA_integer_),
                   "unknown")
})
