# Tests for the Phase 6 annotation-authoring API: create / delete +
# nine per-attribute setters. Each test builds a fresh in-memory
# doc via `pdf_doc_new()` so shipped fixtures stay untouched.

# Helper: fresh doc + page scoped to the caller's frame.
annot_authoring_blank_page <- function(envir = parent.frame()) {
  doc <- pdf_doc_new()
  withr::defer(pdf_doc_close(doc), envir = envir)
  page <- pdf_page_new(doc, page_num = 1L,
                       width = 612, height = 792)
  withr::defer(pdf_page_close(page), envir = envir,
                priority = "first")
  list(doc = doc, page = page)
}

# pdf_annot_new -------------------------------------------------------

test_that("pdf_annot_new creates a handle with the requested subtype", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "highlight",
                     bounds = c(100, 100, 300, 120))
  expect_s3_class(a, "pdfium_annot")
  expect_identical(pdf_annot_subtype(a), "highlight")
  expect_setequal(s$doc$state$dirty_pages, 1L)
  bounds <- pdf_annot_bounds(a)
  expect_equal(unname(bounds["bounds_left"]), 100)
  expect_equal(unname(bounds["bounds_right"]), 300)
})

test_that("pdf_annot_new appends to the page's /Annots array", {
  s <- annot_authoring_blank_page()
  pdf_annot_new(s$page, "text", bounds = c(50, 50, 70, 70))
  pdf_annot_new(s$page, "square", bounds = c(80, 80, 100, 100))
  annots <- pdf_annotations(s$page)
  expect_length(annots, 2L)
  expect_identical(
    vapply(annots, pdf_annot_subtype, character(1L)),
    c("text", "square")
  )
})

test_that("pdf_annot_new rejects unsupported subtypes", {
  s <- annot_authoring_blank_page()
  # PDFium can't create widgets via FPDFPage_CreateAnnot.
  expect_error(pdf_annot_new(s$page, "widget"),
               "(Unknown annotation subtype|illegal or unsupported)")
  expect_error(pdf_annot_new(s$page, "bogus"),
               "Unknown annotation subtype")
})

test_that("pdf_annot_new without bounds creates without setting rect", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "highlight")
  expect_s3_class(a, "pdfium_annot")
})

# pdf_annot_delete ---------------------------------------------------

test_that("pdf_annot_delete removes from page and invalidates", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(50, 50, 70, 70))
  expect_length(pdf_annotations(s$page), 1L)
  ret <- pdf_annot_delete(a)
  expect_identical(ret, s$doc)
  expect_length(pdf_annotations(s$page), 0L)
  expect_false(is_open(a))
  expect_error(pdf_annot_set_contents(a, "x"),
               "has been closed")
})

# pdf_annot_set_bounds -----------------------------------------------

test_that("pdf_annot_set_bounds round-trips through the reader", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "square")
  pdf_annot_set_bounds(a, c(10, 20, 200, 220))
  b <- pdf_annot_bounds(a)
  expect_equal(unname(b["bounds_left"]),   10)
  expect_equal(unname(b["bounds_bottom"]), 20)
  expect_equal(unname(b["bounds_right"]),  200)
  expect_equal(unname(b["bounds_top"]),    220)
})

test_that("pdf_annot_set_bounds validates the vector", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "square")
  expect_error(pdf_annot_set_bounds(a, c(0, 0, 1)), "Assertion on")
  expect_error(pdf_annot_set_bounds(a, c(NA, 0, 1, 2)),
               "Assertion on")
})

# pdf_annot_set_color / pdf_annot_set_interior_color ----------------

test_that("pdf_annot_set_color accepts 0-255 and 0-1 forms", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "highlight",
                     bounds = c(0, 0, 100, 20))
  pdf_annot_set_color(a, color = c(255, 0, 0))
  cl <- pdf_annot_color(a)
  expect_equal(unname(cl["red"]), 1)
  expect_equal(unname(cl["green"]), 0)
  expect_equal(unname(cl["blue"]), 0)

  pdf_annot_set_color(a, color = c(0, 0.5, 1))
  cl <- pdf_annot_color(a)
  expect_equal(unname(cl["red"]), 0)
  # 0.5 * 255 = 127.5 → 128 (rounded). Reader divides back: 128/255.
  expect_equal(unname(cl["green"]), 128 / 255, tolerance = 1e-3)
  expect_equal(unname(cl["blue"]), 1)
})

test_that("pdf_annot_set_color partial overlay preserves other channels", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "square",
                     bounds = c(0, 0, 50, 50))
  pdf_annot_set_color(a, color = c(100, 100, 100, 200))
  pdf_annot_set_color(a, red = 250)
  cl <- pdf_annot_color(a)
  expect_equal(unname(cl["red"]), 250 / 255, tolerance = 1e-3)
  expect_equal(unname(cl["green"]), 100 / 255, tolerance = 1e-3)
  expect_equal(unname(cl["alpha"]), 200 / 255, tolerance = 1e-3)
})

test_that("pdf_annot_set_interior_color round-trips", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "square",
                     bounds = c(0, 0, 50, 50))
  pdf_annot_set_interior_color(a, color = c(0, 255, 0))
  ic <- pdf_annot_interior_color(a)
  expect_equal(unname(ic["green"]), 1)
})

test_that("pdf_annot_set_color rejects bad inputs", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "highlight",
                     bounds = c(0, 0, 100, 20))
  expect_error(pdf_annot_set_color(a, color = c(300, 0, 0)),
               "must be in")
  expect_error(pdf_annot_set_color(a, color = c(1, 1)),
               "Assertion on")
})

# pdf_annot_set_flags ------------------------------------------------

test_that("pdf_annot_set_flags accepts an integer bitmask", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(0, 0, 20, 20))
  # /F bit 3 = Print (bitmask value 4); bit 1 = Invisible (1).
  pdf_annot_set_flags(a, 5L)
  expect_equal(pdf_annot_flags(a), 5L)
  decoded <- pdf_annot_flags_decoded(a)
  expect_true(decoded[["is_invisible"]])
  expect_true(decoded[["is_print"]])
  expect_false(decoded[["is_hidden"]])
})

test_that("pdf_annot_set_flags accepts a named logical", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(0, 0, 20, 20))
  pdf_annot_set_flags(a, c(is_print = TRUE, is_hidden = TRUE))
  decoded <- pdf_annot_flags_decoded(a)
  expect_true(decoded[["is_print"]])
  expect_true(decoded[["is_hidden"]])
  expect_false(decoded[["is_locked"]])
})

test_that("pdf_annot_set_flags rejects unknown bit names", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(0, 0, 20, 20))
  expect_error(
    pdf_annot_set_flags(a, c(is_bogus = TRUE)),
    "Unknown annotation flag bits"
  )
})

test_that("pdf_annot_set_flags rejects negative integers", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(0, 0, 20, 20))
  expect_error(pdf_annot_set_flags(a, -1L), "Assertion on")
})

# String setters: contents / title / subject / dict_value -----------

test_that("pdf_annot_set_contents / _title / _subject round-trip", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "highlight",
                     bounds = c(0, 0, 100, 20))
  pdf_annot_set_contents(a, "Important note")
  pdf_annot_set_title(a, "Reviewer 2")
  pdf_annot_set_subject(a, "Highlight")
  expect_identical(pdf_annot_contents(a), "Important note")
  expect_identical(pdf_annot_title(a), "Reviewer 2")
  expect_identical(pdf_annot_subject(a), "Highlight")
})

test_that("pdf_annot_set_contents handles non-ASCII UTF-8", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(0, 0, 20, 20))
  msg <- enc2utf8("日本語のテスト")
  pdf_annot_set_contents(a, msg)
  expect_identical(pdf_annot_contents(a), msg)
})

test_that("pdf_annot_set_dict_value writes arbitrary keys", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(0, 0, 20, 20))
  pdf_annot_set_dict_value(a, "NM", "annot-uuid-1234")
  out <- pdf_annot_dict_value(a, "NM")
  expect_identical(out$value_string, "annot-uuid-1234")
})

test_that("string setters validate inputs", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "text", bounds = c(0, 0, 20, 20))
  expect_error(pdf_annot_set_contents(a, NA), "Assertion on")
  expect_error(pdf_annot_set_title(a, 1L), "Assertion on")
  expect_error(pdf_annot_set_dict_value(a, "", "value"),
               "Assertion on")
})

# pdf_annot_append_quad ----------------------------------------------

test_that("pdf_annot_append_quad round-trips through the reader", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "highlight",
                     bounds = c(0, 0, 200, 20))
  q <- c(0, 20, 200, 20, 0, 0, 200, 0)
  pdf_annot_append_quad(a, q)
  qp <- pdf_annot_quad_points(a)
  expect_true(is.matrix(qp))
  expect_equal(dim(qp), c(1L, 8L))
  expect_equal(unname(qp[1L, ]), q)
})

test_that("pdf_annot_append_quad validates the vector", {
  s <- annot_authoring_blank_page()
  a <- pdf_annot_new(s$page, "highlight",
                     bounds = c(0, 0, 200, 20))
  expect_error(pdf_annot_append_quad(a, c(0, 0)), "Assertion on")
  expect_error(pdf_annot_append_quad(a, c(rep(0, 7), NA)),
               "Assertion on")
})

# Read-only doc rejection --------------------------------------------

test_that("authoring functions refuse a read-only doc", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(pdf_annot_new(page, "highlight"), "readwrite")
  # Setters on an existing annot also refuse.
  annots <- pdf_annotations(page)
  a <- annots[[1L]]
  expect_error(pdf_annot_set_bounds(a, c(0, 0, 10, 10)),
               "readwrite")
  expect_error(pdf_annot_set_contents(a, "x"), "readwrite")
  expect_error(pdf_annot_set_color(a, color = c(1, 0, 0)),
               "readwrite")
  expect_error(pdf_annot_delete(a), "readwrite")
})

# Closed-handle rejection --------------------------------------------

test_that("authoring functions refuse a closed-page annot handle", {
  doc <- pdf_doc_open(fixture_path("annotated"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  annots <- pdf_annotations(page)
  a <- annots[[1L]]
  pdf_page_close(page)
  expect_error(pdf_annot_set_bounds(a, c(0, 0, 1, 1)),
               "has been closed")
  expect_error(pdf_annot_set_contents(a, "x"),
               "has been closed")
})
