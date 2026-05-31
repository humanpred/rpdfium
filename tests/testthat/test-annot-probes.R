# Tests for the generic annotation dict probe, AP accessor,
# link->annot bridge, direct obj MCID, and focusable-subtypes
# accessors. These un-defer the v0.1.0 Tier 3 items that don't fit
# any existing module.

test_that("pdf_annot_dict_value finds the highlight's /Subj", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # The highlight is annotation_index 2; it carries /Subj=(Important).
  annot <- pdf_annot_at(doc, 2L, page_num = 1L)
  out <- pdf_annot_dict_value(annot, "Subj")
  expect_named(out, c(
    "has_key", "value_type", "value_string",
    "value_number"
  ))
  expect_true(out$has_key)
  expect_equal(out$value_string, "Important")
})

test_that("pdf_annot_dict_value reports has_key=FALSE for missing keys", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annot <- pdf_annot_at(doc, 1L, page_num = 1L)
  out <- pdf_annot_dict_value(annot, "NoSuchKey")
  expect_false(out$has_key)
  expect_true(is.na(out$value_type))
})

test_that("pdf_annot_dict_value validates inputs", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annot <- pdf_annot_at(doc, 1L, page_num = 1L)
  expect_error(
    pdf_annot_dict_value(annot, ""),
    "Assertion on"
  )
  expect_error(
    pdf_annot_dict_value("not-an-annot", "Subj"),
    "Assertion on"
  )
})

test_that("pdf_annot_at validates the index", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_annot_at(doc, 0L), "Assertion on")
  expect_error(pdf_annot_at(doc, 99L), "exceeds")
})

test_that("pdf_annot_appearance returns a string or empty", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annot <- pdf_annot_at(doc, 1L, page_num = 1L)
  # No /AP on any of annotated.pdf's annots — empty string.
  expect_equal(pdf_annot_appearance(annot), "")
  expect_equal(pdf_annot_appearance(annot, mode = "rollover"), "")
})

test_that("pdf_link_annot_at_point returns the link's annot handle", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_link_annot_at_point(doc, 125, 160, page_num = 1L)
  expect_s3_class(out, "pdfium_annot")
  # Link is annotation_index 3 in annotated.pdf.
  expect_equal(out$index, 3L)
  expect_identical(pdf_annot_subtype(out), "link")
})

test_that("pdf_link_annot_at_point returns NULL when no link is near", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_null(pdf_link_annot_at_point(doc, 5, 5, page_num = 1L))
})

test_that("pdf_link_annot_at_point validates x and y", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
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
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(
    pdf_annot_appearance("not-an-annot"),
    "Assertion on"
  )
  annot <- pdf_annot_at(doc, 1L, page_num = 1L)
  expect_error(
    pdf_annot_appearance(annot, mode = "bogus"),
    "should be one of"
  )
})

test_that("pdf_obj_marked_content_id returns NA for untagged content", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  for (obj in pdf_page_objects(page)) {
    expect_true(is.na(pdf_obj_marked_content_id(obj)))
  }
})

test_that("pdf_doc_focusable_subtypes includes widget", {
  out <- pdf_doc_focusable_subtypes(fixture_path("annotated"))
  expect_type(out, "character")
  expect_true("widget" %in% out)
})

# Direct-shim coverage for the C-side branches the high-level API
# can't reach.

test_that("cpp_annot_dict_value returns has_key=FALSE for an out-of-range index", {
  # The R-side pdf_annot_dict_value() validates annot$index before
  # subtracting 1L, so it can't pass an out-of-range zero-based
  # index to the C shim. Calling the shim directly exercises the
  # `annot == nullptr` branch (FPDFPage_GetAnnot returns null for
  # an out-of-range index).
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  out <- pdfium:::cpp_annot_dict_value(page$ptr, 9999L, "Subj")
  expect_false(out$has_key)
  expect_true(is.na(out$value_type))
  expect_true(is.na(out$value_string))
  expect_true(is.na(out$value_number))
})

test_that("cpp_annot_appearance returns empty for an out-of-range index", {
  # Companion to the cpp_annot_dict_value out-of-range test: the
  # FPDFPage_GetAnnot null branch in cpp_annot_appearance is also
  # unreachable from the R-side wrapper.
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_identical(
    pdfium:::cpp_annot_appearance(page$ptr, 9999L, 0L),
    ""
  )
})

test_that("pdf_annot_dict_value reports an empty string when /Subj is set to ''", {
  # Trips the `needed == 2` branch in cpp_annot_dict_value: a key
  # whose value is a zero-length string (UTF-16 NUL only).
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 200, height = 200)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  a <- pdf_annot_new(page, "text", bounds = c(0, 0, 50, 50))
  pdf_annot_set_dict_value(a, "Subj", "")
  out <- pdf_annot_dict_value(a, "Subj")
  expect_true(out$has_key)
  expect_identical(out$value_string, "")
})

test_that("pdf_annot_dict_value reads a number-typed entry", {
  # Trips the FPDF_OBJECT_NUMBER branch in cpp_annot_dict_value.
  # Construct an inline PDF whose single annotation carries a
  # number-typed /F entry (annotation flag bits). PDFium's
  # FPDFAnnot_GetValueType reports FPDF_OBJECT_NUMBER (=2) and
  # FPDFAnnot_GetNumberValue fills the float receiver.
  obj <- function(n, body) paste0(n, " 0 obj\n", body, "\nendobj\n")
  obj1 <- obj(1, "<< /Type /Catalog /Pages 2 0 R >>")
  obj2 <- obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
  obj3 <- obj(3,
              paste0("<< /Type /Page /Parent 2 0 R ",
                     "/MediaBox [0 0 200 200] /Resources <<>> ",
                     "/Annots [4 0 R] >>"))
  obj4 <- obj(4,
              paste0("<< /Type /Annot /Subtype /Text ",
                     "/Rect [20 20 40 40] /Contents (hi) /F 4 >>"))
  header <- charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
  parts <- list(
    header,
    charToRaw(obj1),
    charToRaw(obj2),
    charToRaw(obj3),
    charToRaw(obj4)
  )
  cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
  offs <- cum[seq_len(4L) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  xref <- paste(
    c("xref", "0 5", "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  full <- c(unlist(parts), charToRaw(xref), charToRaw(trailer))
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  doc <- pdf_doc_open(tf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  a <- pdf_annot_at(doc, 1L, page_num = 1L)
  out <- pdf_annot_dict_value(a, "F")
  expect_true(out$has_key)
  # FPDF_OBJECT_NUMBER = 2 (from fpdfview.h).
  expect_identical(out$value_type, 2L)
  expect_equal(out$value_number, 4)
  expect_true(is.na(out$value_string))
})

test_that("pdf_annot_appearance round-trips a non-empty AP string", {
  # Trips the `needed > 2` branch (lines 133-141) of
  # cpp_annot_appearance. pdf_annot_set_appearance writes a non-
  # empty UTF-16LE AP string via FPDFAnnot_SetAP; reading it back
  # via pdf_annot_appearance exercises the two-pass buffer path.
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 200, height = 200)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  a <- pdf_annot_new(page, "stamp", bounds = c(0, 0, 100, 100))
  ap <- "q 1 0 0 rg 0 0 100 100 re f Q"
  pdf_annot_set_appearance(a, mode = "normal", value = ap)
  expect_identical(pdf_annot_appearance(a, mode = "normal"), ap)
})
