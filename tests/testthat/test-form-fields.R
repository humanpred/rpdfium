# Tests for pdf_form_fields(). annotated.pdf carries two AcroForm
# fields on page 1:
#   * Textfield  /T="name"  /TU="Full name" /V="Bob"  rect [50 100 200 120]
#   * Checkbox   /T="agree" /TU="I agree"   /V=/Yes   rect [50 60 70 80]
#     (checked)

test_that("pdf_form_fields returns 0 rows when the doc has no AcroForm", {
  res <- pdf_form_fields(fixture_path("shapes"))
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c(
    "field_index", "page_num", "field_type",
    "field_flags", "is_readonly", "is_required",
    "is_no_export", "is_checked",
    "control_count", "control_index",
    "name", "alternate_name", "value",
    "export_value",
    "bounds_left", "bounds_bottom", "bounds_right",
    "bounds_top", "options",
    "is_option_selected", "additional_actions_js"
  ))
})

test_that("pdf_form_fields exposes control_count/index + additional_actions_js shape", {
  res <- pdf_form_fields(fixture_path("annotated"))
  expect_equal(nrow(res), 2L)
  # Both fields are single-widget — control_count == 1, index == 0.
  expect_identical(res$control_count, c(1L, 1L))
  expect_identical(res$control_index, c(0L, 0L))
  # is_option_selected is empty for non-choice fields.
  expect_true(all(vapply(
    res$is_option_selected, length,
    integer(1L)
  ) == 0L))
  # additional_actions_js: length-4 named character vec per row.
  expect_true(all(vapply(
    res$additional_actions_js, length,
    integer(1L)
  ) == 4L))
  expect_identical(
    names(res$additional_actions_js[[1L]]),
    c("key_stroke", "format", "validate", "calculate")
  )
  expect_true(all(vapply(
    res$additional_actions_js,
    function(x) all(x == ""), logical(1L)
  )))
})

test_that("pdf_form_fields reports the documented text field", {
  res <- pdf_form_fields(fixture_path("annotated"))
  expect_equal(nrow(res), 2L)
  tf <- res[res$field_type == "textfield", ]
  expect_equal(nrow(tf), 1L)
  expect_identical(tf$page_num, 1L)
  expect_identical(tf$name, "name")
  expect_identical(tf$alternate_name, "Full name")
  expect_identical(tf$value, "Bob")
  expect_equal(tf$bounds_left[[1L]], 50)
  expect_equal(tf$bounds_bottom[[1L]], 100)
  expect_equal(tf$bounds_right[[1L]], 200)
  expect_equal(tf$bounds_top[[1L]], 120)
  # Non-checkable types report is_checked as NA.
  expect_true(is.na(tf$is_checked))
  # No special flags set on this field.
  expect_false(tf$is_readonly)
  expect_false(tf$is_required)
  expect_false(tf$is_no_export)
})

test_that("pdf_form_fields reports the documented checkbox state", {
  res <- pdf_form_fields(fixture_path("annotated"))
  cb <- res[res$field_type == "checkbox", ]
  expect_equal(nrow(cb), 1L)
  expect_identical(cb$page_num, 1L)
  expect_identical(cb$name, "agree")
  expect_identical(cb$alternate_name, "I agree")
  # /V=/Yes plus /AS=/Yes means PDFium reads the box as checked.
  expect_true(cb$is_checked)
  expect_equal(cb$bounds_left[[1L]], 50)
  expect_equal(cb$bounds_bottom[[1L]], 60)
})

test_that("pdf_form_fields options column is a list of empty char vecs for non-choice fields", {
  res <- pdf_form_fields(fixture_path("annotated"))
  expect_type(res$options, "list")
  # Neither textfield nor checkbox carries choice options.
  expect_true(all(vapply(res$options, length, integer(1L)) == 0L))
})

test_that("form-field flag decoding handles bits 1-3", {
  # is_readonly = bit 1 (1<<0 = 1)
  # is_required = bit 2 (1<<1 = 2)
  # is_no_export = bit 3 (1<<2 = 4)
  expect_identical(
    pdfium:::form_field_flag_decode(c(0L, 1L, 2L, 4L, 7L), 1L),
    c(FALSE, TRUE, FALSE, FALSE, TRUE)
  )
  expect_identical(
    pdfium:::form_field_flag_decode(c(0L, 1L, 2L, 4L, 7L), 2L),
    c(FALSE, FALSE, TRUE, FALSE, TRUE)
  )
  expect_identical(
    pdfium:::form_field_flag_decode(c(0L, 1L, 2L, 4L, 7L), 3L),
    c(FALSE, FALSE, FALSE, TRUE, TRUE)
  )
})

test_that("pdf_form_fields accepts a path or an open doc", {
  by_path <- pdf_form_fields(fixture_path("annotated"))
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_form_fields(doc)
  expect_identical(by_path, by_doc)
})

test_that("pdf_form_fields rejects bad inputs and closed docs", {
  expect_error(pdf_form_fields(42), "class .pdfium_doc.")
  doc <- pdf_doc_open(fixture_path("annotated"))
  pdf_doc_close(doc)
  expect_error(pdf_form_fields(doc), "Document has been closed")
})

test_that("form_field_type_name maps codes to documented strings", {
  expect_identical(
    pdfium:::form_field_type_name(0L:7L),
    c(
      "unknown", "pushbutton", "checkbox", "radiobutton",
      "combobox", "listbox", "textfield", "signature"
    )
  )
  expect_identical(pdfium:::form_field_type_name(99L), "unknown")
  expect_identical(pdfium:::form_field_type_name(-1L), "unknown")
  expect_identical(
    pdfium:::form_field_type_name(NA_integer_),
    "unknown"
  )
})
