# Tests for pdf_form_fields() (now returns a pdfium_form_field_list).
# annotated.pdf carries two AcroForm fields on page 1:
#   * Textfield  /T="name"  /TU="Full name" /V="Bob"  rect [50 100 200 120]
#   * Checkbox   /T="agree" /TU="I agree"   /V=/Yes   rect [50 60 70 80]
#     (checked)

test_that("pdf_form_fields returns 0 handles when the doc has no AcroForm", {
  res <- pdf_form_fields(fixture_path("shapes"))
  expect_s3_class(res, "pdfium_form_field_list")
  expect_length(res, 0L)
  tbl <- tibble::as_tibble(res)
  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 0L)
  expect_named(tbl, c(
    "field_index", "page_num", "field_type",
    "field_flags", "is_readonly", "is_required",
    "is_no_export", "is_checked",
    "control_count", "control_index",
    "name", "alternate_name", "value",
    "export_value",
    "bounds_left", "bounds_bottom", "bounds_right",
    "bounds_top", "options",
    "is_option_selected", "additional_actions_js",
    "handle", "source"
  ))
})

test_that("pdf_form_fields exposes control_count/index + additional_actions_js shape", {
  res <- tibble::as_tibble(pdf_form_fields(fixture_path("annotated")))
  expect_equal(nrow(res), 2L)
  expect_identical(res$control_count, c(1L, 1L))
  expect_identical(res$control_index, c(0L, 0L))
  expect_true(all(vapply(
    res$is_option_selected, length,
    integer(1L)
  ) == 0L))
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
  res <- tibble::as_tibble(pdf_form_fields(fixture_path("annotated")))
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
  expect_true(is.na(tf$is_checked))
  expect_false(tf$is_readonly)
  expect_false(tf$is_required)
  expect_false(tf$is_no_export)
})

test_that("pdf_form_fields reports the documented checkbox state", {
  res <- tibble::as_tibble(pdf_form_fields(fixture_path("annotated")))
  cb <- res[res$field_type == "checkbox", ]
  expect_equal(nrow(cb), 1L)
  expect_identical(cb$page_num, 1L)
  expect_identical(cb$name, "agree")
  expect_identical(cb$alternate_name, "I agree")
  expect_true(cb$is_checked)
  expect_equal(cb$bounds_left[[1L]], 50)
  expect_equal(cb$bounds_bottom[[1L]], 60)
})

test_that("pdf_form_fields options column is a list of empty char vecs for non-choice fields", {
  res <- tibble::as_tibble(pdf_form_fields(fixture_path("annotated")))
  expect_type(res$options, "list")
  expect_true(all(vapply(res$options, length, integer(1L)) == 0L))
})

test_that("form-field flag decoding handles bits 1-3", {
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
  by_path <- tibble::as_tibble(
    pdf_form_fields(fixture_path("annotated"))
  )
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- tibble::as_tibble(pdf_form_fields(doc))
  # Drop handle + source: handles differ between calls, source differs
  # because by_path opens its own doc.
  drop_handle <- function(t) {
    t[, !names(t) %in% c("handle", "source")]
  }
  expect_identical(drop_handle(by_path), drop_handle(by_doc))
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

# -- New handle-based tests --

test_that("pdf_form_fields returns a list of pdfium_form_field handles", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  expect_s3_class(fields, "pdfium_form_field_list")
  expect_length(fields, 2L)
  for (f in fields) {
    expect_s3_class(f, "pdfium_form_field")
    expect_s3_class(f, "pdfium_annot") # IS-A
  }
})

test_that("pdfium_form_field_list print method shows field type + index", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  txt <- capture.output(print(fields))
  expect_true(any(grepl("2 field\\(s\\)", txt)))
  expect_true(any(grepl("textfield|checkbox", txt)))
})

test_that("pdf_form_field_type and friends work on a single handle", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  f1 <- fields[[1L]]
  expect_type(pdf_form_field_type(f1), "character")
  expect_type(pdf_form_field_type_code(f1), "integer")
  expect_equal(pdf_form_field_page_num(f1), 1L)
  # Since pdfium_form_field IS-A pdfium_annot, annot accessors work
  # too.
  expect_equal(pdf_annot_subtype(f1), "widget")
})

test_that("as_pdfium_form_field_list round-trips from a tibble", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  tbl <- tibble::as_tibble(fields)
  back <- as_pdfium_form_field_list(tbl)
  expect_s3_class(back, "pdfium_form_field_list")
  expect_length(back, length(fields))
  expect_identical(back[[1L]]$ptr, fields[[1L]]$ptr)
})

test_that("as_pdfium_form_field_list is a no-op on existing handle lists", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  expect_identical(as_pdfium_form_field_list(fields), fields)
})

test_that("as_pdfium_form_field_list accepts a plain list of handles", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  plain <- unclass(fields)
  back <- as_pdfium_form_field_list(plain)
  expect_s3_class(back, "pdfium_form_field_list")
  expect_length(back, length(fields))
})

test_that("as_pdfium_form_field_list errors on unrecognised input", {
  expect_error(as_pdfium_form_field_list("nope"),
               "must be a .pdfium_form_field_list.")
  expect_error(
    as_pdfium_form_field_list(tibble::tibble(handle = list(),
                                             source = list())),
    "zero-row"
  )
})

test_that("zero-field doc round-trips through as_tibble", {
  fields <- pdf_form_fields(fixture_path("shapes"))
  expect_length(fields, 0L)
  tbl <- tibble::as_tibble(fields)
  expect_equal(nrow(tbl), 0L)
})

test_that("pdf_form_field_type rejects non-form-field input", {
  expect_error(pdf_form_field_type("nope"), "Assertion on")
  expect_error(pdf_form_field_type_code(42), "Assertion on")
  expect_error(pdf_form_field_page_num(NULL), "Assertion on")
})

test_that("pdf_form_field_type rejects closed handles", {
  # Closing the field's parent page invalidates the form_field
  # handle (see pdfium_annot's is_open chain).
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  fields <- pdf_form_fields(doc)
  f1 <- fields[[1L]]
  page <- f1$page
  pdf_page_close(page)
  expect_error(pdf_form_field_type(f1), "has been closed")
})

test_that("pdfium_form_field print method shows type + index + page", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  out <- capture.output(print(fields[[1L]]))
  expect_true(any(grepl("field 1", out)))
  expect_true(any(grepl("page 1", out)))
})

test_that("pdfium_form_field_list print method truncates beyond 5 entries", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  many <- structure(
    c(unclass(fields), unclass(fields), unclass(fields)),
    source = attr(fields, "source"),
    pages_used = attr(fields, "pages_used"),
    class = c("pdfium_form_field_list", "list")
  )
  txt <- capture.output(print(many))
  expect_true(any(grepl("more", txt)))
})

# Per-handle form_field getters -------------------------------------

test_that("per-handle getters read the textfield's documented attrs", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  type_names <- vapply(fields, pdf_form_field_type, character(1L))
  tf <- fields[type_names == "textfield"][[1L]]
  expect_identical(pdf_form_field_name(tf), "name")
  expect_identical(pdf_form_field_alternate_name(tf), "Full name")
  expect_identical(pdf_form_field_value(tf), "Bob")
  expect_type(pdf_form_field_export_value(tf), "character")
  expect_type(pdf_form_field_flags(tf), "integer")
  decoded <- pdf_form_field_flags_decoded(tf)
  expect_named(decoded, c("is_readonly", "is_required", "is_no_export"))
  expect_false(decoded[["is_readonly"]])
  expect_false(decoded[["is_required"]])
  expect_false(decoded[["is_no_export"]])
  expect_true(is.na(pdf_form_field_is_checked(tf)))
  expect_true(is.na(pdf_form_field_control_count(tf)) ||
                pdf_form_field_control_count(tf) >= 0L)
  expect_length(pdf_form_field_options(tf), 0L)
  expect_length(pdf_form_field_is_option_selected(tf), 0L)
  aa <- pdf_form_field_additional_actions_js(tf)
  expect_length(aa, 4L)
  expect_named(aa, c("key_stroke", "format", "validate", "calculate"))
  expect_true(all(aa == ""))
})

test_that("per-handle getters read the checkbox's documented attrs", {
  fields <- pdf_form_fields(fixture_path("annotated"))
  type_names <- vapply(fields, pdf_form_field_type, character(1L))
  cb <- fields[type_names == "checkbox"][[1L]]
  expect_identical(pdf_form_field_name(cb), "agree")
  expect_identical(pdf_form_field_alternate_name(cb), "I agree")
  expect_true(pdf_form_field_is_checked(cb))
})

test_that("per-handle getters reject non-form-field input", {
  expect_error(pdf_form_field_name("nope"), "Assertion on")
  expect_error(pdf_form_field_value(42), "Assertion on")
  expect_error(pdf_form_field_flags(NULL), "Assertion on")
  expect_error(pdf_form_field_flags_decoded(0L), "Assertion on")
  expect_error(pdf_form_field_is_checked(0L), "Assertion on")
  expect_error(pdf_form_field_control_count(0L), "Assertion on")
  expect_error(pdf_form_field_control_index(0L), "Assertion on")
  expect_error(pdf_form_field_options(0L), "Assertion on")
  expect_error(pdf_form_field_is_option_selected(0L), "Assertion on")
  expect_error(pdf_form_field_additional_actions_js(0L), "Assertion on")
  expect_error(pdf_form_field_alternate_name(0L), "Assertion on")
  expect_error(pdf_form_field_export_value(0L), "Assertion on")
})

test_that("per-handle getters reject closed-page form fields", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  fields <- pdf_form_fields(doc)
  f1 <- fields[[1L]]
  pdf_page_close(f1$page)
  for (fn in list(
    pdf_form_field_name, pdf_form_field_alternate_name,
    pdf_form_field_value, pdf_form_field_export_value,
    pdf_form_field_flags, pdf_form_field_flags_decoded,
    pdf_form_field_is_checked, pdf_form_field_control_count,
    pdf_form_field_control_index, pdf_form_field_options,
    pdf_form_field_is_option_selected,
    pdf_form_field_additional_actions_js
  )) {
    expect_error(fn(f1), "has been closed")
  }
})
