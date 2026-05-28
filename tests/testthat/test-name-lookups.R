# Tests for the name- / point-based lookup helpers:
# pdf_doc_named_dest_by_name(), pdf_doc_bookmark_find(), pdf_form_field_at_point().

# Build a two-chapter outline PDF used to exercise the
# find_bookmark_in_walk() short-circuit at the "this subtree doesn't
# contain the target, advance to next sibling" return-false branch.
# Layout:
#   Chapter 1                         <- has one nested section, not target
#     Section 1.1
#   Chapter 2                         <- the search target
# Finding "Chapter 2" forces the walker to recurse into Chapter 1,
# fail to find the target in that subtree, return false, and only
# then advance to Chapter 2 at the top level.
make_two_chapter_outline_pdf <- function() {
  obj <- function(n, body) paste0(n, " 0 obj\n", body, "\nendobj\n")
  obj1 <- obj(1, paste0(
    "<< /Type /Catalog /Pages 2 0 R /Outlines 3 0 R >>"
  ))
  obj2 <- obj(2, "<< /Type /Pages /Kids [4 0 R] /Count 1 >>")
  obj3 <- obj(3, paste0(
    "<< /Type /Outlines /First 5 0 R /Last 7 0 R /Count 2 >>"
  ))
  obj4 <- obj(4, paste0(
    "<< /Type /Page /Parent 2 0 R ",
    "/MediaBox [0 0 300 300] /Resources <<>> >>"
  ))
  # Chapter 1 with one child (Section 1.1).
  obj5 <- obj(5, paste0(
    "<< /Title (Chapter 1) /Parent 3 0 R /Next 7 0 R ",
    "/First 6 0 R /Last 6 0 R /Count 1 ",
    "/Dest [4 0 R /Fit] >>"
  ))
  obj6 <- obj(6, paste0(
    "<< /Title (Section 1.1) /Parent 5 0 R ",
    "/Dest [4 0 R /Fit] >>"
  ))
  # Chapter 2 (no children). This is the search target.
  obj7 <- obj(7, paste0(
    "<< /Title (Chapter 2) /Parent 3 0 R /Prev 5 0 R ",
    "/Dest [4 0 R /Fit] >>"
  ))
  header <- charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
  parts <- list(
    header,
    charToRaw(obj1), charToRaw(obj2), charToRaw(obj3),
    charToRaw(obj4), charToRaw(obj5), charToRaw(obj6),
    charToRaw(obj7)
  )
  cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
  offs <- cum[seq_len(7L) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  xref <- paste(
    c(
      "xref", "0 8", "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")
    ),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size 8 /Root 1 0 R >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  c(unlist(parts), charToRaw(xref), charToRaw(trailer))
}

# Build a tiny single-page PDF that declares two named destinations
# (`dest_one` -> XYZ with explicit coordinates, `dest_fit` -> /Fit
# with no coordinates) via the catalog's /Dests dictionary. Used to
# exercise the success branch of cpp_named_dest_by_name() which the
# bundled shapes.pdf / outline.pdf can't reach.
make_named_dest_pdf <- function() {
  obj <- function(n, body) paste0(n, " 0 obj\n", body, "\nendobj\n")
  obj1 <- obj(1, "<< /Type /Catalog /Pages 2 0 R /Dests 4 0 R >>")
  obj2 <- obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
  obj3 <- obj(3, paste0(
    "<< /Type /Page /Parent 2 0 R ",
    "/MediaBox [0 0 300 300] /Resources <<>> >>"
  ))
  obj4 <- obj(4, paste0(
    "<< /dest_one [3 0 R /XYZ 100 200 0.5] ",
    "/dest_fit [3 0 R /Fit] >>"
  ))
  header <- charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
  parts <- list(
    header,
    charToRaw(obj1), charToRaw(obj2),
    charToRaw(obj3), charToRaw(obj4)
  )
  cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
  offs <- cum[seq_len(4L) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  xref <- paste(
    c(
      "xref", "0 5", "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")
    ),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  c(unlist(parts), charToRaw(xref), charToRaw(trailer))
}

test_that("pdf_doc_bookmark_find walks past non-target subtrees", {
  # Searching for "Chapter 2" in the two-chapter outline forces the
  # walker to descend into Chapter 1's subtree (which doesn't contain
  # the target), return false from the recursive call, then advance
  # to the next top-level sibling.
  doc <- pdf_doc_open(source = make_two_chapter_outline_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  bm <- pdf_doc_bookmark_find(doc, "Chapter 2")
  expect_s3_class(bm, "pdfium_bookmark")
  # Pre-order index for Chapter 2 = 3 (Chapter 1 = 1, Section 1.1 = 2,
  # Chapter 2 = 3).
  expect_equal(bm$index, 3L)
  expect_equal(bm$parent_index, 0L)
  expect_equal(bm$level, 1L)
  expect_identical(pdf_bookmark_title(bm), "Chapter 2")
})

test_that("pdf_doc_bookmark_find returns a pdfium_bookmark handle", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bm <- pdf_doc_bookmark_find(doc, "Chapter 1")
  expect_s3_class(bm, "pdfium_bookmark")
  expect_equal(bm$index, 1L)
  expect_equal(bm$parent_index, 0L)
  expect_equal(bm$level, 1L)
  expect_identical(pdf_bookmark_title(bm), "Chapter 1")
  bm2 <- pdf_doc_bookmark_find(doc, "Section 1.1")
  expect_equal(bm2$index, 2L)
  expect_equal(bm2$parent_index, 1L)
  expect_equal(bm2$level, 2L)
  expect_identical(pdf_bookmark_title(bm2), "Section 1.1")
  bm3 <- pdf_doc_bookmark_find(doc, "Section 1.2")
  expect_equal(bm3$index, 3L)
  expect_equal(bm3$parent_index, 1L)
  expect_equal(bm3$level, 2L)
  expect_null(pdf_doc_bookmark_find(doc, "Missing"))
})

test_that("pdf_doc_bookmark_find handle round-trips into bookmark list", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bm <- pdf_doc_bookmark_find(doc, "Chapter 1")
  back <- as_pdfium_bookmark_list(list(bm))
  expect_s3_class(back, "pdfium_bookmark_list")
  expect_length(back, 1L)
  expect_identical(back[[1L]]$ptr, bm$ptr)
})

test_that("pdf_doc_bookmark_find validates title input", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_doc_bookmark_find(doc, ""), "Assertion on")
  expect_error(pdf_doc_bookmark_find(doc, NA_character_), "Assertion on")
  expect_error(pdf_doc_bookmark_find(doc, c("a", "b")), "Assertion on")
  expect_error(pdf_doc_bookmark_find(doc, 42), "Assertion on")
})

test_that("pdf_doc_named_dest_by_name returns the right shape", {
  # outline.pdf has no /Dests dict so any name should return found=FALSE.
  out <- pdf_doc_named_dest_by_name(fixture_path("outline"), "nope")
  expect_named(out, c(
    "found", "page", "dest_view", "dest_x",
    "dest_y", "dest_zoom"
  ))
  expect_false(out$found)
  expect_true(is.na(out$page))
})

test_that("pdf_doc_named_dest_by_name validates `name`", {
  expect_error(
    pdf_doc_named_dest_by_name(fixture_path("shapes"), ""),
    "Assertion on"
  )
  expect_error(
    pdf_doc_named_dest_by_name(fixture_path("shapes"), NA_character_),
    "Assertion on"
  )
})

test_that("pdf_doc_named_dest_by_name resolves explicit XYZ destinations", {
  doc <- pdf_doc_open(source = make_named_dest_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_doc_named_dest_by_name(doc, "dest_one")
  expect_true(out$found)
  expect_equal(out$page, 1L)
  expect_equal(out$dest_view, "xyz")
  expect_equal(out$dest_x, 100)
  expect_equal(out$dest_y, 200)
  expect_equal(out$dest_zoom, 0.5)
})

test_that("pdf_doc_named_dest_by_name resolves /Fit destinations", {
  doc <- pdf_doc_open(source = make_named_dest_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_doc_named_dest_by_name(doc, "dest_fit")
  expect_true(out$found)
  expect_equal(out$page, 1L)
  expect_equal(out$dest_view, "fit")
  # /Fit carries no x/y/zoom coordinates.
  expect_true(is.na(out$dest_x))
  expect_true(is.na(out$dest_y))
  expect_true(is.na(out$dest_zoom))
})

test_that("pdf_form_field_at_point detects the textfield at its centre", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # The textfield rect in annotated.pdf is [50 100 200 120] —
  # sample its centre.
  out <- pdf_form_field_at_point(doc, 125, 110, page_num = 1L)
  expect_named(out, c("field_type", "z_order"))
  expect_equal(out$field_type, "textfield")
  expect_type(out$z_order, "integer")
  expect_gte(out$z_order, 0L)
})

test_that("pdf_form_field_at_point returns NA when no field is near", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_form_field_at_point(doc, 5, 5, page_num = 1L)
  expect_true(is.na(out$field_type))
  expect_true(is.na(out$z_order))
})

test_that("pdf_form_field_at_point validates x and y", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_form_field_at_point(doc, NA, 10), "Assertion on")
  expect_error(pdf_form_field_at_point(doc, 10, NA), "Assertion on")
})

# The R-side wrappers always pass an externalptr to the C++ shims,
# so the EXTPTRSXP guards at the top of each shim are only reachable
# through direct `pdfium:::cpp_*` calls. Exercise them with a few
# non-extptr values so the validation paths get instrumented.
test_that("name-lookup cpp shims reject non-externalptr inputs", {
  for (bad in list(NULL, 42, "string", list(), TRUE, NA)) {
    expect_error(
      pdfium:::cpp_named_dest_by_name(bad, "x"),
      "external pointer"
    )
    expect_error(
      pdfium:::cpp_bookmark_find_handle(bad, "x"),
      "external pointer"
    )
    expect_error(
      pdfium:::cpp_form_field_at_point(bad, bad, 0, 0),
      "external pointer"
    )
  }
})

test_that("cpp_form_field_at_point rejects a non-externalptr page", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # Valid doc, but non-extptr page argument trips the page guard
  # at the top of the shim.
  for (bad_page in list(NULL, 42, "string", list(), TRUE, NA)) {
    expect_error(
      pdfium:::cpp_form_field_at_point(doc$ptr, bad_page, 0, 0),
      "external pointer"
    )
  }
})

test_that("name-lookup cpp shims reject a closed doc handle", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  ptr <- doc$ptr
  pdf_doc_close(doc)
  expect_error(
    pdfium:::cpp_named_dest_by_name(ptr, "x"),
    "Document handle"
  )
  expect_error(
    pdfium:::cpp_bookmark_find_handle(ptr, "x"),
    "Document handle"
  )
})

test_that("cpp_form_field_at_point rejects a closed page handle", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  page_ptr <- page$ptr
  pdf_page_close(page)
  expect_error(
    pdfium:::cpp_form_field_at_point(doc$ptr, page_ptr, 0, 0),
    "Page handle"
  )
})
