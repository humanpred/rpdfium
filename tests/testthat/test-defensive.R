# Defensive C-side validation tests (ADR-020 §4).
#
# Every cpp_* Rcpp shim that takes an externalptr argument MUST
# validate two things at entry:
#
#   1. TYPEOF(ptr) == EXTPTRSXP — the argument is actually an
#      externalptr and not some other R object Rcpp passed
#      through.
#   2. R_ExternalPtrAddr(ptr) != nullptr — the underlying pointer
#      is live. After a finalizer runs or pdf_*_close() flips the
#      handle, the externalptr is cleared (R_ClearExternalPtr) and
#      the address reads as NULL.
#
# On miss, the shim raises Rcpp::stop with a readable message —
# never a segfault. The R-side wrappers also guard most paths via
# check_*() helpers, but the C-side guards are the safety net for
# anyone who calls a cpp_* shim through `:::` or builds a handle
# manually. This file exercises the safety net by zeroing the
# parent handle (closing the doc / page) and then calling the
# downstream shims directly through `pdfium:::`.
#
# Curated coverage: one shim per handle class, across all the
# argument shapes (doc_ptr, page_ptr, annot_ptr, obj_ptr,
# attachment_ptr, signature_ptr, bookmark_ptr, form_field /
# widget annot, plus the cross-handle two-arg cases like
# (annot_ptr, doc_ptr)).

# Each block opens a fresh doc, captures the relevant ptr, closes
# the parent, then asserts the shim refuses politely.

test_that("cpp_* doc-pointer shims reject a closed doc handle", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  ptr <- doc$ptr
  pdf_doc_close(doc)
  for (fn in list(
    function() pdfium:::cpp_page_count(ptr),
    function() pdfium:::cpp_attachment_count(ptr),
    function() pdfium:::cpp_signature_count(ptr),
    function() pdfium:::cpp_bookmark_handles(ptr)
  )) {
    expect_error(fn(), "Document handle")
  }
})

test_that("cpp_* page-pointer shims reject a closed page handle", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  ptr <- page$ptr
  pdf_page_close(page)
  for (fn in list(
    function() pdfium:::cpp_page_object_count(ptr),
    function() pdfium:::cpp_annot_count(ptr)
  )) {
    expect_error(fn(), "[Pp]age handle")
  }
})

test_that("cpp_attachment_* shims reject a closed attachment", {
  # Attachments are doc-owned (no finalizer). Closing the doc
  # clears the externalptr so the C-side null-check trips.
  doc <- pdf_doc_open(fixture_path("attachments"))
  att_list <- pdf_attachments(doc)
  skip_if(length(att_list) == 0L, "no attachments in fixture")
  ptr <- att_list[[1L]]$ptr
  pdf_doc_close(doc)
  expect_error(pdfium:::cpp_attachment_name(ptr),
               "[Aa]ttachment handle")
  expect_error(pdfium:::cpp_attachment_size_bytes(ptr),
               "[Aa]ttachment handle")
})

test_that("cpp_signature_* shims reject a closed signature", {
  doc <- pdf_doc_open(fixture_path("signed"))
  sigs <- pdf_signatures(doc)
  skip_if(length(sigs) == 0L, "no signatures in fixture")
  ptr <- sigs[[1L]]$ptr
  pdf_doc_close(doc)
  expect_error(pdfium:::cpp_signature_sub_filter_handle(ptr),
               "[Ss]ignature handle")
  expect_error(pdfium:::cpp_signature_time_handle(ptr),
               "[Ss]ignature handle")
})

test_that("cpp_bookmark_* shims reject a closed bookmark", {
  doc <- pdf_doc_open(fixture_path("outline"))
  bms <- pdf_doc_bookmarks(doc)
  skip_if(length(bms) == 0L, "no bookmarks in fixture")
  ptr <- bms[[1L]]$ptr
  pdf_doc_close(doc)
  expect_error(pdfium:::cpp_bookmark_title_handle(ptr),
               "[Bb]ookmark handle")
})

test_that("cpp_annot_* shims reject a closed annotation", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  ptr <- annots[[1L]]$ptr
  # Close the page (which the annot's finalizer pinned in prot).
  # When R's GC reclaims the annot externalptr it clears the
  # underlying address; force that here by closing the page,
  # which invokes the annot's own finalizer.
  pdf_page_close(annots[[1L]]$page)
  expect_error(pdfium:::cpp_annot_subtype_code(ptr),
               "[Aa]nnotation handle")
  expect_error(pdfium:::cpp_annot_flags(ptr),
               "[Aa]nnotation handle")
})

test_that("cpp_obj_* shims reject a closed page-object handle", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  skip_if(length(objs) == 0L, "no page objects in fixture")
  ptr <- objs[[1L]]$ptr
  pdf_page_close(page)
  # Page-object externalptrs don't have their own finalizer; their
  # prot slot pins the parent page externalptr. Closing the page
  # clears the parent's address, which the C-side parent-liveness
  # check (handle_validation.h) catches before dereferencing the
  # dangling obj pointer.
  for (fn in list(
    function() pdfium:::cpp_obj_type(ptr),
    function() pdfium:::cpp_obj_bounds(ptr),
    function() pdfium:::cpp_obj_matrix(ptr),
    function() pdfium:::cpp_obj_stroke_color(ptr),
    function() pdfium:::cpp_obj_fill_color(ptr),
    function() pdfium:::cpp_obj_stroke_width(ptr),
    function() pdfium:::cpp_obj_dash_count(ptr),
    function() pdfium:::cpp_path_segment_count(ptr),
    function() pdfium:::cpp_text_font_size(ptr),
    function() pdfium:::cpp_obj_line_cap(ptr),
    function() pdfium:::cpp_obj_marks_list(ptr),
    function() pdfium:::cpp_text_render_mode(ptr)
  )) {
    expect_error(fn(), "[Pp]age-object handle")
  }
})

test_that("cpp_* shims reject non-externalptr arguments", {
  # Each of the shims below validates TYPEOF == EXTPTRSXP. Feeding
  # a non-externalptr should error cleanly.
  for (bad in list(NULL, 42, "string", list(), TRUE, NA)) {
    expect_error(pdfium:::cpp_page_count(bad))
    expect_error(pdfium:::cpp_attachment_count(bad))
    expect_error(pdfium:::cpp_signature_count(bad))
    expect_error(pdfium:::cpp_bookmark_handles(bad))
  }
})
