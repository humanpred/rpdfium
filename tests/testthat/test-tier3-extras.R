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
# ADR-017 / Phase 2.5c. The legacy doc+index shim
# `cpp_attachment_dict_value` is still exported (see
# src/tier3_extras.cpp) for backward compatibility with older
# downstream callers and direct-shim coverage tests; the four
# tests below exercise each of its result-shape branches.

test_that("cpp_attachment_dict_value reads a string-typed key", {
  # Open a writable attachments fixture, then SetData to materialise
  # the /Params subdict (PDFium auto-populates Size/CreationDate/
  # CheckSum on FPDFAttachment_SetFile). CreationDate is a real PDF
  # date string -> drives the full UTF-16 read path in
  # cpp_attachment_dict_value (lines 144-161).
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  pdf_attachment_set_data(att, pdf_attachment_data(att))
  out <- pdfium:::cpp_attachment_dict_value(doc$ptr, 0L, "CreationDate")
  expect_true(out$has_key)
  # value_type 3 is the FPDF_OBJECT_STRING enum value.
  expect_identical(out$value_type, 3L)
  # Date strings start with "D:" per the PDF spec.
  expect_match(out$value, "^D:")
})

test_that("cpp_attachment_dict_value reports missing keys", {
  # has_key = FALSE branch (lines 130-135).
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdfium:::cpp_attachment_dict_value(doc$ptr, 0L, "NoSuchKey")
  expect_false(out$has_key)
  expect_true(is.na(out$value_type))
  expect_true(is.na(out$value))
})

test_that("cpp_attachment_dict_value flags non-string value types", {
  # `Size` is FPDF_OBJECT_NUMBER (= 2) — drives the wrong-type
  # branch (lines 137-142).
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  pdf_attachment_set_data(att, pdf_attachment_data(att))
  out <- pdfium:::cpp_attachment_dict_value(doc$ptr, 0L, "Size")
  expect_true(out$has_key)
  expect_identical(out$value_type, 2L)
  expect_true(is.na(out$value))
})

test_that("cpp_attachment_dict_value handles empty-string values", {
  # Write a zero-length string to a /Params key — exercises the
  # `need <= 2` short path (lines 144-150) where PDFium reports
  # only the terminating NUL.
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  pdf_attachment_set_data(att, pdf_attachment_data(att))
  pdf_attachment_set_dict_value(att, "Desc", "")
  out <- pdfium:::cpp_attachment_dict_value(doc$ptr, 0L, "Desc")
  expect_true(out$has_key)
  # Empty string comes back as "" via the short path, not NA.
  expect_identical(out$value, "")
})

test_that("cpp_attachment_dict_value rejects an out-of-range index", {
  # FPDFDoc_GetAttachment returns NULL for an index past the end,
  # exercising the early-return branch (lines 124-128).
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdfium:::cpp_attachment_dict_value(doc$ptr, 99L, "Subtype")
  expect_false(out$has_key)
  expect_true(is.na(out$value_type))
  expect_true(is.na(out$value))
})

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

# ---- pdf_text_obj_at_char --------------------------------------------------

test_that("pdf_text_obj_at_char returns the text page-object owning a char", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  obj <- pdf_text_obj_at_char(doc, 1L)
  expect_s3_class(obj, "pdfium_obj")
  expect_identical(obj$type, "text")
  # The accessor agrees with the index-only path.
  i <- pdf_text_char_obj_index(doc, 1L)
  expect_equal(obj$index, as.integer(i))
})

test_that("pdf_text_obj_at_char returns NULL when char has no text obj", {
  # PDFium returns NULL for char indices past the page's char count
  # and for chars without a backing text object. The accessor
  # propagates that as NULL rather than constructing a bogus
  # pdfium_obj.
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # 99999 is well past any real char on the page; PDFium returns NULL.
  obj <- pdf_text_obj_at_char(doc, 99999L)
  expect_null(obj)
})

test_that("pdf_text_obj_at_char validates char_index", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_text_obj_at_char(doc, 0L), "Assertion on")
  expect_error(pdf_text_obj_at_char(doc, NA), "Assertion on")
  expect_error(pdf_text_obj_at_char(doc, -1L), "Assertion on")
})
