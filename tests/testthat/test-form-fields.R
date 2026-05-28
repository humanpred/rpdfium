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
  # Checkboxes report control_count/index of 1/1 in PDFium's
  # accounting (single-control group). Exercise the happy path so
  # the +1 branch is covered.
  expect_identical(pdf_form_field_control_count(cb), 1L)
  expect_identical(pdf_form_field_control_index(cb), 1L)
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

# Defensive C-side guards ------------------------------------------
#
# Every cpp_form_field_*_handle shim validates (annot_ptr, doc_ptr) at
# entry: each must be EXTPTRSXP and must have a non-NULL address. Only
# the R wrappers normally feed those guards; calling the shims via `:::`
# with a non-externalptr exercises the TYPEOF != EXTPTRSXP arm so it's
# covered in addition to the closed-handle (NULL-address) arm above.

test_that("cpp_form_field_*_handle shims reject non-externalptr args", {
  # Each shim takes (annot_ptr, doc_ptr) in that order. Hitting the
  # EXTPTRSXP arm only needs one bad arg; we feed both as integer so
  # ff_annot_from_ptr trips first for some shims and ff_doc_from_ptr
  # trips for others where the doc arg is validated first.
  shims <- list(
    pdfium:::cpp_form_field_name_handle,
    pdfium:::cpp_form_field_alternate_name_handle,
    pdfium:::cpp_form_field_value_handle,
    pdfium:::cpp_form_field_export_value_handle,
    pdfium:::cpp_form_field_flags_handle,
    pdfium:::cpp_form_field_is_checked_handle,
    pdfium:::cpp_form_field_control_count_handle,
    pdfium:::cpp_form_field_control_index_handle,
    pdfium:::cpp_form_field_options_handle,
    pdfium:::cpp_form_field_is_option_selected_handle,
    pdfium:::cpp_form_field_additional_actions_handle
  )
  for (shim in shims) {
    # Integer for both args → trips one of ff_*_from_ptr's
    # TYPEOF != EXTPTRSXP guards.
    expect_error(shim(42L, 42L), "externalptr")
  }
})

test_that("cpp_form_field_*_handle shims reject closed doc handles", {
  # Closed-doc path: open a form-bearing doc, capture the doc's
  # externalptr, close the doc (which clears the address), then call
  # each shim with a still-live annot externalptr from another doc
  # paired with the now-null doc_ptr. Hits the ff_doc_from_ptr
  # "Document handle is NULL" branch.
  doc <- pdf_doc_open(fixture_path("annotated"))
  fields <- pdf_form_fields(doc)
  annot_ptr <- fields[[1L]]$ptr
  doc_ptr <- doc$ptr
  pdf_doc_close(doc)  # clears doc_ptr's address; annot_ptr remains live
  shims <- list(
    pdfium:::cpp_form_field_name_handle,
    pdfium:::cpp_form_field_alternate_name_handle,
    pdfium:::cpp_form_field_value_handle,
    pdfium:::cpp_form_field_export_value_handle,
    pdfium:::cpp_form_field_flags_handle,
    pdfium:::cpp_form_field_is_checked_handle,
    pdfium:::cpp_form_field_control_count_handle,
    pdfium:::cpp_form_field_control_index_handle,
    pdfium:::cpp_form_field_options_handle,
    pdfium:::cpp_form_field_is_option_selected_handle,
    pdfium:::cpp_form_field_additional_actions_handle
  )
  for (shim in shims) {
    expect_error(shim(annot_ptr, doc_ptr),
                 "[Dd]ocument handle is NULL")
  }
})

# cpp_form_fields_list -- defensive doc_ptr guards -----------------

test_that("cpp_form_fields_list rejects non-externalptr arg", {
  expect_error(pdfium:::cpp_form_fields_list(42L),
               "external pointer")
})

test_that("cpp_form_fields_list rejects a closed doc", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  doc_ptr <- doc$ptr
  pdf_doc_close(doc)
  expect_error(pdfium:::cpp_form_fields_list(doc_ptr),
               "[Dd]ocument handle is closed")
})

# Combobox + AA JavaScript via inline-constructed PDF --------------
#
# The shipped fixtures only carry textfield + checkbox widgets, so the
# read_form_options, read_option_selected, and read_additional_actions_js
# code paths in src/form_fields.cpp (and the matching shim paths in
# src/form_field_per_handle.cpp) never get exercised by them. Build a
# minimal hand-crafted PDF inline (same byte-construction pattern as
# test-bookmarks.R's circular-outline test) so those paths see real,
# non-empty data.

# Helper: assemble a PDF body + xref + trailer for `obj_bodies`.
# `obj_bodies` is a vector of complete "N 0 obj\n...\nendobj\n"
# strings; we compute offsets, append the xref/trailer, and return
# the byte vector ready for writeBin().
form_fields_build_pdf <- function(obj_bodies) {
  header <- "%PDF-1.4\n"
  body <- paste0(header, paste0(obj_bodies, collapse = ""))
  bytes <- charToRaw(body)
  offs <- nchar(header) +
    c(0L, cumsum(nchar(obj_bodies))[-length(obj_bodies)])
  xref_off <- length(bytes)
  size <- length(obj_bodies) + 1L  # +1 for the 0-th free entry
  xref <- charToRaw(paste0(
    "xref\n0 ", size, "\n0000000000 65535 f \n",
    paste(sprintf("%010d 00000 n ", offs), collapse = "\n"), " \n"
  ))
  trailer <- charToRaw(sprintf(
    "trailer << /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n",
    size, xref_off
  ))
  c(bytes, xref, trailer)
}

test_that("pdf_form_fields decodes combobox /Opt labels + selection state", {
  # Combobox widget with /Opt [(One)(Two)(Three)] and /V (One). PDFium
  # treats /Ch fields with single-select as a combobox/listbox; the
  # mapping reaches FPDFAnnot_GetOptionCount > 0 so both
  # read_form_options (lines 65-76 of form_fields.cpp) and
  # read_option_selected (lines 86-91) get exercised.
  obj_bodies <- c(
    paste0("1 0 obj\n<< /Type /Catalog /Pages 2 0 R ",
           "/AcroForm << /Fields [4 0 R] >> >>\nendobj\n"),
    "2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n",
    paste0("3 0 obj\n<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 400 400] /Resources << >> ",
           "/Annots [4 0 R] >>\nendobj\n"),
    paste0("4 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Ch ",
           "/T (combo1) /Rect [10 10 100 30] ",
           "/Opt [(One) (Two) (Three)] /V (One) >>\nendobj\n")
  )
  full <- form_fields_build_pdf(obj_bodies)
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  res <- tibble::as_tibble(pdf_form_fields(tf))
  expect_equal(nrow(res), 1L)
  expect_identical(res$options[[1L]], c("One", "Two", "Three"))
  expect_identical(res$is_option_selected[[1L]],
                   c(TRUE, FALSE, FALSE))
})

test_that("pdf_form_fields surfaces an empty-/Opt combobox as zero options", {
  # Combobox with no /Opt at all -> FPDFAnnot_GetOptionCount returns 0
  # so read_form_options returns empty and read_option_selected hits
  # the n <= 0 short-circuit (line 85). Already covered by other
  # fixtures, but pinning the behaviour explicitly is cheap.
  obj_bodies <- c(
    paste0("1 0 obj\n<< /Type /Catalog /Pages 2 0 R ",
           "/AcroForm << /Fields [4 0 R] >> >>\nendobj\n"),
    "2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n",
    paste0("3 0 obj\n<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 400 400] /Resources << >> ",
           "/Annots [4 0 R] >>\nendobj\n"),
    paste0("4 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Ch ",
           "/T (combo_empty) /Rect [10 10 100 30] >>\nendobj\n")
  )
  full <- form_fields_build_pdf(obj_bodies)
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  res <- tibble::as_tibble(pdf_form_fields(tf))
  expect_equal(nrow(res), 1L)
  expect_length(res$options[[1L]], 0L)
  expect_length(res$is_option_selected[[1L]], 0L)
})

test_that("pdf_form_fields decodes /AA JavaScript triggers", {
  # Widget with the full set of additional-actions JavaScript triggers
  # (/K /F /V /C) — PDFium maps these onto the AACTION_KEY_STROKE,
  # AACTION_FORMAT, AACTION_VALIDATE, AACTION_CALCULATE enum values
  # exposed by FPDFAnnot_GetFormAdditionalActionJavaScript. Triggers
  # the needed > 2 branch in read_additional_actions_js (lines
  # 112-118 of form_fields.cpp).
  obj_bodies <- c(
    paste0("1 0 obj\n<< /Type /Catalog /Pages 2 0 R ",
           "/AcroForm << /Fields [4 0 R] >> >>\nendobj\n"),
    "2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n",
    paste0("3 0 obj\n<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 400 400] /Resources << >> ",
           "/Annots [4 0 R] >>\nendobj\n"),
    paste0("4 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Tx ",
           "/T (text_with_aa) /Rect [10 10 100 30] ",
           "/AA << ",
           "/K << /S /JavaScript /JS (alert(0)) >> ",
           "/F << /S /JavaScript /JS (alert(1)) >> ",
           "/V << /S /JavaScript /JS (alert(2)) >> ",
           "/C << /S /JavaScript /JS (alert(3)) >> ",
           ">> >>\nendobj\n")
  )
  full <- form_fields_build_pdf(obj_bodies)
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  res <- tibble::as_tibble(pdf_form_fields(tf))
  expect_equal(nrow(res), 1L)
  aa <- res$additional_actions_js[[1L]]
  expect_named(aa, c("key_stroke", "format", "validate", "calculate"))
  expect_identical(aa[["key_stroke"]], "alert(0)")
  expect_identical(aa[["format"]],     "alert(1)")
  expect_identical(aa[["validate"]],   "alert(2)")
  expect_identical(aa[["calculate"]],  "alert(3)")
})

test_that("per-handle accessors read combobox options + AA JS", {
  # Same inline PDF but exercised via the handle-based per-field
  # accessors, which run through src/form_field_per_handle.cpp's
  # cpp_form_field_options_handle, cpp_form_field_is_option_selected_handle,
  # and cpp_form_field_additional_actions_handle. Lines 170-182,
  # 194-198, and 227-233 of that file.
  obj_bodies <- c(
    paste0("1 0 obj\n<< /Type /Catalog /Pages 2 0 R ",
           "/AcroForm << /Fields [4 0 R 5 0 R] >> >>\nendobj\n"),
    "2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n",
    paste0("3 0 obj\n<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 400 400] /Resources << >> ",
           "/Annots [4 0 R 5 0 R] >>\nendobj\n"),
    paste0("4 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Ch ",
           "/T (combo_h) /Rect [10 10 100 30] ",
           "/Opt [(Alpha) (Beta)] /V (Alpha) >>\nendobj\n"),
    paste0("5 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Tx ",
           "/T (text_aa_h) /Rect [10 50 100 70] ",
           "/AA << ",
           "/K << /S /JavaScript /JS (k_js) >> ",
           "/F << /S /JavaScript /JS (f_js) >> ",
           "/V << /S /JavaScript /JS (v_js) >> ",
           "/C << /S /JavaScript /JS (c_js) >> ",
           ">> >>\nendobj\n")
  )
  full <- form_fields_build_pdf(obj_bodies)
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  doc <- pdf_doc_open(tf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  fields <- pdf_form_fields(doc)
  expect_length(fields, 2L)
  combo <- fields[[1L]]
  expect_identical(pdf_form_field_options(combo), c("Alpha", "Beta"))
  expect_identical(pdf_form_field_is_option_selected(combo),
                   c(TRUE, FALSE))
  text <- fields[[2L]]
  aa <- pdf_form_field_additional_actions_js(text)
  expect_named(aa, c("key_stroke", "format", "validate", "calculate"))
  expect_identical(aa[["key_stroke"]], "k_js")
  expect_identical(aa[["format"]],     "f_js")
  expect_identical(aa[["validate"]],   "v_js")
  expect_identical(aa[["calculate"]],  "c_js")
})
