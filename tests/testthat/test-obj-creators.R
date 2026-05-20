# Tests for the Phase 5 page-object creators (pdf_path_new,
# pdf_rect_new, pdf_text_new) and the inverse pdf_obj_delete.
# Each creator builds a fresh in-memory doc via `pdf_doc_new()`
# so the test doesn't perturb any shipped fixture.

# Helper: fresh doc + page, scheduled to close in the caller.
creators_blank_page <- function(envir = parent.frame()) {
  doc <- pdf_doc_new()
  withr::defer(pdf_doc_close(doc), envir = envir)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  withr::defer(pdf_page_close(page), envir = envir,
                priority = "first")
  list(doc = doc, page = page)
}

# pdf_path_new --------------------------------------------------------

test_that("pdf_path_new inserts a path on the page", {
  s <- creators_blank_page()
  before <- length(pdf_page_objects(s$page))
  path <- pdf_path_new(s$page, 10, 20)
  expect_s3_class(path, "pdfium_obj")
  expect_identical(path$type, "path")
  expect_setequal(s$doc$state$dirty_pages, 1L)
  expect_equal(length(pdf_page_objects(s$page)), before + 1L)
})

test_that("pdf_path_new defaults x/y to 0", {
  s <- creators_blank_page()
  path <- pdf_path_new(s$page)
  segs <- pdf_path_segments(path)
  expect_equal(nrow(segs), 1L)
  expect_equal(segs$x[[1L]], 0)
  expect_equal(segs$y[[1L]], 0)
})

test_that("pdf_path_new composes with Phase 4 appenders", {
  s <- creators_blank_page()
  path <- pdf_path_new(s$page, 0, 0)
  pdf_path_line_to(path, 100, 0)
  pdf_path_line_to(path, 100, 100)
  pdf_path_line_to(path, 0, 100)
  pdf_path_close(path)
  # Close flags the last segment as `close_figure = TRUE`; it
  # doesn't insert a new segment row. So 1 moveto + 3 linetos = 4.
  segs <- pdf_path_segments(path)
  expect_equal(nrow(segs), 4L)
  expect_identical(segs$segment_type,
                   c("moveto", rep("lineto", 3L)))
  expect_true(tail(segs$close_figure, 1L))
})

# pdf_rect_new --------------------------------------------------------

test_that("pdf_rect_new inserts a closed rectangle path", {
  s <- creators_blank_page()
  rect <- pdf_rect_new(s$page, 50, 50, 100, 80)
  expect_identical(rect$type, "path")
  segs <- pdf_path_segments(rect)
  # PDFium emits a rect as moveto + 3 linetos with the last marked
  # close_figure (matches the existing pdf_path_segments contract).
  expect_gte(nrow(segs), 4L)
  expect_identical(segs$segment_type[[1L]], "moveto")
  expect_true(any(segs$close_figure))
})

test_that("pdf_rect_new validates dimensions", {
  s <- creators_blank_page()
  expect_error(pdf_rect_new(s$page, 0, 0, -1, 10), "Assertion on")
  expect_error(pdf_rect_new(s$page, 0, 0, 10, NA), "Assertion on")
  expect_error(pdf_rect_new(s$page, Inf, 0, 10, 10), "Assertion on")
})

# pdf_text_new --------------------------------------------------------

test_that("pdf_text_new inserts a text obj with the given content", {
  s <- creators_blank_page()
  txt <- pdf_text_new(s$page, "Hello", font = "Helvetica",
                       font_size = 18, x = 50, y = 700)
  expect_identical(txt$type, "text")
  expect_identical(pdf_text_content(txt), "Hello")
})

test_that("pdf_text_new accepts every PDF standard font", {
  s <- creators_blank_page()
  fonts <- c("Helvetica", "Helvetica-Bold", "Times-Roman",
             "Times-BoldItalic", "Courier", "Symbol",
             "ZapfDingbats")
  for (f in fonts) {
    t <- pdf_text_new(s$page, "abc", font = f, font_size = 10)
    expect_identical(t$type, "text")
  }
})

test_that("pdf_text_new rejects non-standard font names", {
  s <- creators_blank_page()
  expect_error(pdf_text_new(s$page, "x", font = "Comic Sans"),
               "Assertion on")
})

test_that("pdf_text_new accepts empty text content", {
  s <- creators_blank_page()
  t <- pdf_text_new(s$page, "")
  expect_identical(t$type, "text")
  # Empty text-obj returns empty content via the reader.
  expect_identical(pdf_text_content(t), "")
})

test_that("pdf_text_new validates font_size + x + y", {
  s <- creators_blank_page()
  expect_error(pdf_text_new(s$page, "x", font_size = -1),
               "Assertion on")
  expect_error(pdf_text_new(s$page, "x", x = NA),
               "Assertion on")
})

# pdf_obj_delete ------------------------------------------------------

test_that("pdf_obj_delete removes the obj and invalidates the handle", {
  s <- creators_blank_page()
  rect <- pdf_rect_new(s$page, 0, 0, 50, 50)
  txt <- pdf_text_new(s$page, "x")
  before <- length(pdf_page_objects(s$page))
  ret <- pdf_obj_delete(rect)
  expect_identical(ret, s$doc)
  expect_equal(length(pdf_page_objects(s$page)), before - 1L)
  expect_false(is_open(rect))
  # Other handles still work.
  expect_true(is_open(txt))
})

test_that("pdf_obj_delete-then-mutate refuses the deleted handle", {
  s <- creators_blank_page()
  rect <- pdf_rect_new(s$page, 0, 0, 50, 50)
  pdf_obj_delete(rect)
  expect_error(pdf_path_set_fill(rect, color = c(1, 0, 0)),
               "no longer valid")
  expect_error(pdf_obj_set_matrix(rect, c(1, 0, 0, 1, 0, 0)),
               "no longer valid")
  expect_error(pdf_obj_delete(rect), "no longer valid")
})

# Read-only doc rejection --------------------------------------------

test_that("creators refuse a read-only doc", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(pdf_path_new(page), "readwrite")
  expect_error(pdf_rect_new(page, 0, 0, 10, 10), "readwrite")
  expect_error(pdf_text_new(page, "x"), "readwrite")
  # delete also refuses
  objs <- pdf_page_objects(page)
  expect_error(pdf_obj_delete(objs[[1L]]), "readwrite")
})

# Closed-page rejection ----------------------------------------------

test_that("creators refuse a closed page", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, 1L, 612, 792)
  pdf_page_close(page)
  expect_error(pdf_path_new(page), "Page has been closed")
  expect_error(pdf_rect_new(page, 0, 0, 10, 10),
               "Page has been closed")
  expect_error(pdf_text_new(page, "x"), "Page has been closed")
})
