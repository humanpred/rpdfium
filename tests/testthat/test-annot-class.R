# Tests for the pdfium_annot S3 class, per-attribute getters, and
# the as_tibble / as_pdfium_annot_list round-trip introduced by
# ADR-017 + the Phase 2.5 reader refactor.

test_that("pdf_annotations returns a pdfium_annot_list of handles", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  expect_s3_class(annots, "pdfium_annot_list")
  expect_length(annots, 5L)
  for (a in annots) {
    expect_s3_class(a, "pdfium_annot")
  }
})

test_that("pdfium_annot_list print method names the count", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  txt <- capture.output(print(annots))
  expect_true(any(grepl("5 annotation\\(s\\)", txt)))
})

test_that("pdfium_annot_list print method truncates beyond 5 entries", {
  # Build a synthetic list of 7 annots by cloning. We use the same
  # underlying handles five times to exercise the "... and N more"
  # branch without needing a 6+-annot fixture.
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  many <- structure(
    c(unclass(annots), unclass(annots)[1L:2L]),
    source = attr(annots, "source"),
    class = c("pdfium_annot_list", "list")
  )
  txt <- capture.output(print(many))
  expect_true(any(grepl("more", txt)))
})

test_that("pdfium_annot print shows subtype + index", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  out <- capture.output(print(annots[[1L]]))
  expect_true(any(grepl("text", out)))
  expect_true(any(grepl("annot 1", out)))
})

test_that("per-attribute getters return expected types", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  a <- pdf_annot_at(doc, 1L, page_num = 1L) # text annot
  expect_equal(pdf_annot_subtype(a), "text")
  expect_type(pdf_annot_subtype_code(a), "integer")
  expect_type(pdf_annot_flags(a), "integer")
  expect_named(
    pdf_annot_flags_decoded(a),
    c("is_invisible", "is_hidden", "is_print",
      "is_no_view", "is_read_only", "is_locked")
  )
  bounds <- pdf_annot_bounds(a)
  expect_named(
    bounds,
    c("bounds_left", "bounds_bottom", "bounds_right", "bounds_top")
  )
  expect_equal(bounds[["bounds_left"]], 20)
  expect_equal(bounds[["bounds_top"]], 270)
  expect_equal(pdf_annot_contents(a), "Hello")
  expect_equal(pdf_annot_title(a), "Alice")
  expect_type(pdf_annot_subject(a), "character")
  expect_named(pdf_annot_color(a),
               c("red", "green", "blue", "alpha"))
  expect_named(pdf_annot_interior_color(a),
               c("red", "green", "blue", "alpha"))
  expect_type(pdf_annot_border_width(a), "double")
  expect_type(pdf_annot_font_size(a), "double")
  expect_named(pdf_annot_font_color(a),
               c("red", "green", "blue"))
})

test_that("pdf_annot_color reads the highlight's /C", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  hl <- pdf_annot_at(doc, 2L, page_num = 1L)
  expect_equal(pdf_annot_subtype(hl), "highlight")
  col <- pdf_annot_color(hl)
  expect_equal(col[["red"]], 229 / 255, tolerance = 1e-3)
  expect_equal(col[["alpha"]], 1.0)
})

test_that("as_tibble.pdfium_annot_list carries handle and source", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  tbl <- tibble::as_tibble(annots)
  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 5L)
  expect_true("handle" %in% names(tbl))
  expect_true("source" %in% names(tbl))
  # Each row's handle is the corresponding pdfium_annot.
  for (i in seq_len(nrow(tbl))) {
    expect_s3_class(tbl$handle[[i]], "pdfium_annot")
  }
  # Source is the same pdfium_page on every row.
  expect_s3_class(tbl$source[[1L]], "pdfium_page")
})

test_that("as_pdfium_annot_list round-trips from tibble", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  tbl <- tibble::as_tibble(annots)
  back <- as_pdfium_annot_list(tbl)
  expect_s3_class(back, "pdfium_annot_list")
  expect_length(back, length(annots))
  # Same R objects preserved.
  expect_identical(back[[1L]]$ptr, annots[[1L]]$ptr)
})

test_that("as_pdfium_annot_list is a no-op on existing handle lists", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  back <- as_pdfium_annot_list(annots)
  expect_identical(back, annots)
})

test_that("as_pdfium_annot_list accepts a plain list of handles", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  # unclass() strips the pdfium_annot_list class, leaving a bare
  # list of pdfium_annot handles.
  plain <- unclass(annots)
  back <- as_pdfium_annot_list(plain)
  expect_s3_class(back, "pdfium_annot_list")
  expect_length(back, length(annots))
})

test_that("as_pdfium_annot_list errors on unrecognised input", {
  expect_error(as_pdfium_annot_list("nope"),
               "must be a .pdfium_annot_list.")
  expect_error(as_pdfium_annot_list(tibble::tibble(x = 1)),
               "must be a .pdfium_annot_list.")
  expect_error(as_pdfium_annot_list(tibble::tibble(handle = list(),
                                                   source = list())),
               "zero-row")
})

test_that("zero-annotation page round-trips through as_tibble", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  expect_length(annots, 0L)
  tbl <- tibble::as_tibble(annots)
  expect_equal(nrow(tbl), 0L)
})

test_that("pdfium_annot becomes closed when its page closes", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  annots <- pdf_annotations(page)
  a <- annots[[1L]]
  expect_true(is_open(a))
  pdf_page_close(page)
  expect_false(is_open(a))
  expect_error(pdf_annot_subtype(a), "has been closed")
})

test_that("per-attribute readers reject non-annot input", {
  expect_error(pdf_annot_subtype("not-an-annot"), "Assertion on")
  expect_error(pdf_annot_bounds(42), "Assertion on")
})
