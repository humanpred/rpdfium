# Tests for the Phase 3 page-object styling setters. Each test
# opens shapes.pdf readwrite, mutates an object, and verifies the
# matching reader sees the change. The doc's dirty-pages set
# should track every mutation so pdf_save() flushes it.

# Helper: open shapes.pdf readwrite + return the first obj of the
# requested type, with cleanup scheduled in the caller's frame so
# each test_that body sees a clean handle for one shapes.pdf load.
# `fixture_path` is defined in helper-fixtures.R; lintr can't see
# it from the helper's body so we suppress the false positive.
setters_first_obj <- function(type,
                                envir = parent.frame()) {
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)  # nolint
  withr::defer(pdf_doc_close(doc), envir = envir)
  page <- pdf_page_load(doc, 1L)
  withr::defer(pdf_page_close(page), envir = envir, priority = "first")
  objs <- pdf_page_objects(page)
  types <- vapply(objs, function(o) o$type, character(1L))
  obj <- objs[types == type][[1L]]
  list(doc = doc, page = page, obj = obj)
}
setters_first_path <- function(envir = parent.frame()) {
  setters_first_obj("path", envir = envir)
}
setters_first_text <- function(envir = parent.frame()) {
  setters_first_obj("text", envir = envir)
}

# pdf_obj_set_matrix --------------------------------------------------

test_that("pdf_obj_set_matrix accepts a 3x3 matrix and marks dirty", {
  s <- setters_first_path()
  m <- matrix(c(2, 0, 0, 0, 2, 0, 10, 20, 1),
              nrow = 3L, ncol = 3L, byrow = FALSE)
  ret <- pdf_obj_set_matrix(s$obj, m)
  expect_identical(ret, s$doc)
  expect_setequal(s$doc$state$dirty_pages, 1L)
  expect_equal(pdf_obj_matrix(s$obj), m)
})

test_that("pdf_obj_set_matrix accepts a length-6 vector", {
  s <- setters_first_path()
  pdf_obj_set_matrix(s$obj, c(1.5, 0, 0, 1.5, 5, 5))
  M <- pdf_obj_matrix(s$obj)
  expect_equal(M[1L, 1L], 1.5)
  expect_equal(M[2L, 2L], 1.5)
  expect_equal(M[1L, 3L], 5)
})

test_that("pdf_obj_set_matrix rejects non-affine 3x3", {
  s <- setters_first_path()
  bad <- matrix(c(1, 0, 0, 0, 1, 0, 0, 0, 2),
                nrow = 3L, ncol = 3L)  # bottom-right is 2, not 1
  expect_error(pdf_obj_set_matrix(s$obj, bad), "bottom row")
})

test_that("pdf_obj_set_matrix rejects wrong-length vector", {
  s <- setters_first_path()
  expect_error(pdf_obj_set_matrix(s$obj, c(1, 0, 0, 1, 0)), "Assertion on")
})

# pdf_obj_set_active --------------------------------------------------

test_that("pdf_obj_set_active toggles the active flag", {
  s <- setters_first_path()
  pdf_obj_set_active(s$obj, FALSE)
  expect_false(pdf_obj_is_active(s$obj))
  pdf_obj_set_active(s$obj, TRUE)
  expect_true(pdf_obj_is_active(s$obj))
})

test_that("pdf_obj_set_active validates inputs", {
  s <- setters_first_path()
  expect_error(pdf_obj_set_active(s$obj, NA), "Assertion on")
  expect_error(pdf_obj_set_active(s$obj, "yes"), "Assertion on")
  expect_error(pdf_obj_set_active("nope", TRUE), "Assertion on")
})

# pdf_obj_set_blend_mode ----------------------------------------------

test_that("pdf_obj_set_blend_mode accepts the documented names", {
  s <- setters_first_path()
  # No getter for blend mode — just verify the call doesn't error.
  expect_invisible(pdf_obj_set_blend_mode(s$obj, "Multiply"))
  expect_invisible(pdf_obj_set_blend_mode(s$obj, "Normal"))
})

test_that("pdf_obj_set_blend_mode rejects unknown modes", {
  s <- setters_first_path()
  expect_error(pdf_obj_set_blend_mode(s$obj, "bogus"), "Assertion on")
})

# pdf_path_set_stroke -------------------------------------------------

test_that("pdf_path_set_stroke updates color + width via composite", {
  s <- setters_first_path()
  pdf_path_set_stroke(s$obj, color = c(255, 128, 0), width = 4)
  st <- pdf_path_stroke(s$obj)
  expect_equal(unname(st[1:3]), c(255, 128, 0))
  expect_equal(unname(st["width"]), 4)
})

test_that("pdf_path_set_stroke accepts 0-1 doubles via auto-detect", {
  s <- setters_first_path()
  pdf_path_set_stroke(s$obj, color = c(1, 0, 0, 0.5))
  st <- pdf_path_stroke(s$obj)
  expect_equal(unname(st["red"]), 255)
  expect_equal(unname(st["alpha"]), 128)  # 0.5 * 255 rounded
})

test_that("pdf_path_set_stroke partial update preserves other channels", {
  s <- setters_first_path()
  pdf_path_set_stroke(s$obj, color = c(100, 100, 100, 200))
  pdf_path_set_stroke(s$obj, red = 250)
  st <- pdf_path_stroke(s$obj)
  expect_equal(unname(st["red"]), 250)
  expect_equal(unname(st["green"]), 100)
  expect_equal(unname(st["alpha"]), 200)
  # Individual green / blue / alpha overrides each take the same
  # path through overlay_rgba_partial.
  pdf_path_set_stroke(s$obj, green = 50)
  pdf_path_set_stroke(s$obj, blue = 75)
  pdf_path_set_stroke(s$obj, alpha = 99)
  st <- pdf_path_stroke(s$obj)
  expect_equal(unname(st["green"]), 50)
  expect_equal(unname(st["blue"]), 75)
  expect_equal(unname(st["alpha"]), 99)
})

test_that("pdf_path_set_stroke rejects bad color", {
  s <- setters_first_path()
  expect_error(pdf_path_set_stroke(s$obj, color = c(300, 0, 0)),
               "must be in")
  expect_error(pdf_path_set_stroke(s$obj, color = c(1, 1)),
               "Assertion on")
  expect_error(pdf_path_set_stroke(s$obj, width = -1),
               "Assertion on")
})

# pdf_path_set_fill ---------------------------------------------------

test_that("pdf_path_set_fill updates fill via composite", {
  s <- setters_first_path()
  pdf_path_set_fill(s$obj, color = c(0, 200, 50, 255))
  expect_equal(unname(pdf_path_fill(s$obj)[1:4]), c(0, 200, 50, 255))
})

test_that("pdf_path_set_fill partial overrides one channel", {
  s <- setters_first_path()
  pdf_path_set_fill(s$obj, color = c(100, 100, 100))
  pdf_path_set_fill(s$obj, alpha = 64)
  expect_equal(unname(pdf_path_fill(s$obj)["alpha"]), 64)
})

# pdf_path_set_line_cap / _line_join ---------------------------------

test_that("pdf_path_set_line_cap round-trips", {
  s <- setters_first_path()
  for (cap in c("butt", "round", "projecting_square")) {
    pdf_path_set_line_cap(s$obj, cap)
    expect_identical(pdf_path_line_cap(s$obj), cap)
  }
})

test_that("pdf_path_set_line_join round-trips", {
  s <- setters_first_path()
  for (join in c("miter", "round", "bevel")) {
    pdf_path_set_line_join(s$obj, join)
    expect_identical(pdf_path_line_join(s$obj), join)
  }
})

test_that("pdf_path_set_line_cap / _line_join reject unknown names", {
  s <- setters_first_path()
  expect_error(pdf_path_set_line_cap(s$obj, "square"), "Assertion on")
  expect_error(pdf_path_set_line_join(s$obj, "sharp"), "Assertion on")
})

# pdf_path_set_dash --------------------------------------------------

test_that("pdf_path_set_dash round-trips", {
  s <- setters_first_path()
  pdf_path_set_dash(s$obj, c(5, 3, 2, 3), phase = 1.5)
  d <- pdf_path_dash(s$obj)
  expect_equal(d$array, c(5, 3, 2, 3))
  expect_equal(d$phase, 1.5)
})

test_that("pdf_path_set_dash clears the dash with an empty array", {
  s <- setters_first_path()
  pdf_path_set_dash(s$obj, c(5, 3))
  pdf_path_set_dash(s$obj, numeric(0))
  expect_length(pdf_path_dash(s$obj)$array, 0L)
})

test_that("pdf_path_set_dash validates inputs", {
  s <- setters_first_path()
  expect_error(pdf_path_set_dash(s$obj, c(5, NA)), "Assertion on")
  expect_error(pdf_path_set_dash(s$obj, c(5, -1)), "Assertion on")
  expect_error(pdf_path_set_dash(s$obj, c(5), phase = NA), "Assertion on")
})

# pdf_path_set_draw_mode ---------------------------------------------

test_that("pdf_path_set_draw_mode round-trips", {
  s <- setters_first_path()
  pdf_path_set_draw_mode(s$obj, "winding", stroke = TRUE)
  dm <- pdf_path_draw_mode(s$obj)
  expect_identical(dm$fill_mode, "winding")
  expect_true(dm$stroke)
  pdf_path_set_draw_mode(s$obj, "even_odd", stroke = FALSE)
  dm <- pdf_path_draw_mode(s$obj)
  expect_identical(dm$fill_mode, "even_odd")
  expect_false(dm$stroke)
})

# pdf_text_set_content -----------------------------------------------

test_that("pdf_text_set_content replaces text content", {
  s <- setters_first_text()
  pdf_text_set_content(s$obj, "Hello")
  # PDFium re-encodes; the round-trip depends on the embedded
  # font's CMap. For the Cairo-built shapes.pdf the embedded font
  # is a synthetic subset; just verify the call succeeded and the
  # page is marked dirty.
  expect_setequal(s$doc$state$dirty_pages, 1L)
})

# pdf_text_set_render_mode -------------------------------------------

test_that("pdf_text_set_render_mode round-trips", {
  s <- setters_first_text()
  for (mode in c("fill", "stroke", "fill_stroke", "invisible")) {
    pdf_text_set_render_mode(s$obj, mode)
    expect_identical(pdf_text_render_mode(s$obj), mode)
  }
})

# pdf_text_set_font_size ----------------------------------------------

test_that("pdf_text_set_font_size changes the font size and persists", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 200, height = 200)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  obj <- pdf_text_new(page, "Hello", font_size = 12)
  ret <- pdf_text_set_font_size(obj, 30)
  expect_identical(ret, doc)
  expect_equal(pdf_text_font_size(obj), 30)
  expect_setequal(doc$state$dirty_pages, 1L)
  # Zero is allowed, mirroring pdf_text_new(font_size = 0).
  pdf_text_set_font_size(obj, 0)
  expect_equal(pdf_text_font_size(obj), 0)
  pdf_text_set_font_size(obj, 18.5)
  doc2 <- pdf_doc_open(source = pdf_save_to_raw(doc))
  on.exit(pdf_doc_close(doc2), add = TRUE)
  expect_equal(pdf_text_font_size(pdf_page_objects(doc2)[[1L]]), 18.5)
})

test_that("pdf_text_set_font_size rejects bad sizes and read-only docs", {
  s <- setters_first_text()
  expect_error(pdf_text_set_font_size(s$obj, -1), "Assertion on 'size'")
  expect_error(pdf_text_set_font_size(s$obj, NA_real_),
               "Assertion on 'size'")
  expect_error(pdf_text_set_font_size(s$obj, Inf), "Assertion on 'size'")
  expect_error(pdf_text_set_font_size(s$obj, c(1, 2)),
               "Assertion on 'size'")
  ro <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(ro), add = TRUE)
  objs <- pdf_page_objects(ro)
  txt <- objs[vapply(objs, function(o) o$type == "text", logical(1L))]
  expect_error(pdf_text_set_font_size(txt[[1L]], 10), "readwrite")
})

# pdf_obj_add_mark / pdf_obj_remove_mark -----------------------------

test_that("pdf_obj_add_mark adds a content mark with params", {
  s <- setters_first_path()
  before <- nrow(pdf_obj_marks(s$obj))
  pdf_obj_add_mark(s$obj, "Span",
                   params = list(Lang = "en-US", MCID = 7L))
  marks <- pdf_obj_marks(s$obj)
  expect_equal(nrow(marks), before + 1L)
  new_mark <- marks[nrow(marks), ]
  expect_identical(new_mark$name, "Span")
  # Parameters land in the params list-column.
  p <- new_mark$params[[1L]]
  expect_identical(p$Lang, "en-US")
  expect_identical(p$MCID, 7L)
})

test_that("pdf_obj_remove_mark removes by 1-based index", {
  s <- setters_first_path()
  pdf_obj_add_mark(s$obj, "Span")
  pdf_obj_add_mark(s$obj, "Artifact")
  before <- nrow(pdf_obj_marks(s$obj))
  pdf_obj_remove_mark(s$obj, before)
  after <- nrow(pdf_obj_marks(s$obj))
  expect_equal(after, before - 1L)
})

test_that("cpp_obj_remove_mark rejects an out-of-range mark index", {
  # Direct cpp::: call: the R wrapper only checks mark_index >= 1L
  # so passing a too-large index lands in the cpp-side
  # "No content mark at index" stop.
  s <- setters_first_path()
  expect_error(
    pdfium:::cpp_obj_remove_mark(s$obj$ptr, 99L),
    "No content mark"
  )
})

test_that("cpp_obj_mark_set_int_param rejects an out-of-range mark index", {
  s <- setters_first_path()
  expect_error(
    pdfium:::cpp_obj_mark_set_int_param(
      s$doc$ptr, s$obj$ptr, 99L, "Lang", 1L
    ),
    "No content mark"
  )
})

test_that("cpp_obj_mark_set_string_param rejects an out-of-range mark index", {
  s <- setters_first_path()
  expect_error(
    pdfium:::cpp_obj_mark_set_string_param(
      s$doc$ptr, s$obj$ptr, 99L, "Lang", "en"
    ),
    "No content mark"
  )
})

test_that("pdf_obj_add_mark rejects bad params", {
  s <- setters_first_path()
  expect_error(
    pdf_obj_add_mark(s$obj, "Span", params = list(Bad = TRUE)),
    "character or numeric"
  )
  expect_error(
    pdf_obj_add_mark(s$obj, ""),
    "Assertion on"
  )
})

# pdf_obj_add_existing_mark -------------------------------------------

test_that("pdf_obj_add_existing_mark shares one mark between objects", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 200, height = 200)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  a <- pdf_rect_new(page, 0, 0, 10, 10)
  b <- pdf_rect_new(page, 20, 0, 10, 10)
  # Painted, so the rectangles survive the save below.
  pdf_path_set_draw_mode(a, fill_mode = "winding", stroke = FALSE)
  pdf_path_set_draw_mode(b, fill_mode = "winding", stroke = FALSE)
  pdf_obj_add_mark(a, "Span", params = list(MCID = 3L, Lang = "en"))
  ret <- pdf_obj_add_existing_mark(b, a, 1L)
  expect_identical(ret, doc)
  marks_b <- pdf_obj_marks(b)
  expect_identical(marks_b$name, "Span")
  expect_identical(marks_b$params[[1L]]$MCID, 3L)
  # Shared, not copied: a parameter removed through `b` is gone from
  # `a` too.
  pdf_obj_mark_remove_param(b, 1L, "Lang")
  expect_null(pdf_obj_marks(a)$params[[1L]]$Lang)
  # Both objects keep the mark through a save / reload.
  doc2 <- pdf_doc_open(source = pdf_save_to_raw(doc))
  on.exit(pdf_doc_close(doc2), add = TRUE)
  reloaded <- lapply(pdf_page_objects(doc2), pdf_obj_marks)
  expect_length(reloaded, 2L)
  for (m in reloaded) {
    expect_identical(m$name, "Span")
    expect_identical(m$params[[1L]]$MCID, 3L)
  }
})

test_that("pdf_obj_add_existing_mark validates its inputs", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 200, height = 200)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  a <- pdf_rect_new(page, 0, 0, 10, 10)
  b <- pdf_rect_new(page, 20, 0, 10, 10)
  expect_error(pdf_obj_add_existing_mark(b, a, 1L),
               "no content mark at index 1")
  pdf_obj_add_mark(a, "Span")
  expect_error(pdf_obj_add_existing_mark(b, a, 0L),
               "Assertion on 'mark_index'")
  expect_error(pdf_obj_add_existing_mark(b, "a", 1L), "Assertion on 'src'")
  other <- pdf_doc_new()
  on.exit(pdf_doc_close(other), add = TRUE)
  other_page <- pdf_page_new(other, page_num = 1L, width = 50, height = 50)
  on.exit(pdf_page_close(other_page), add = TRUE, after = FALSE)
  c_obj <- pdf_rect_new(other_page, 0, 0, 5, 5)
  expect_error(pdf_obj_add_existing_mark(c_obj, a, 1L), "same document")
  expect_length(pdf_obj_marks(c_obj)$name, 0L)
  ro <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(ro), add = TRUE)
  ro_obj <- pdf_page_objects(ro)[[1L]]
  expect_error(pdf_obj_add_existing_mark(ro_obj, ro_obj, 1L), "readwrite")
})

# Read-only doc rejection --------------------------------------------

test_that("setters refuse a read-only doc", {
  # Default readwrite = FALSE; setters must trip assert_readwrite.
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  paths <- objs[vapply(objs, function(o) o$type == "path", logical(1L))]
  p <- paths[[1L]]
  expect_error(pdf_obj_set_active(p, FALSE), "readwrite")
  expect_error(pdf_path_set_stroke(p, width = 1), "readwrite")
  expect_error(pdf_obj_add_mark(p, "Span"), "readwrite")
})

# Type-restriction enforcement ---------------------------------------

test_that("path-only setters refuse non-path objects", {
  s <- setters_first_text()
  expect_error(pdf_path_set_stroke(s$obj, width = 1), "Assertion on")
  expect_error(pdf_path_set_fill(s$obj, color = c(1, 0, 0)),
               "Assertion on")
  expect_error(pdf_path_set_line_cap(s$obj, "round"), "Assertion on")
  expect_error(pdf_path_set_dash(s$obj, c(1, 2)), "Assertion on")
})

test_that("text-only setters refuse non-text objects", {
  s <- setters_first_path()
  expect_error(pdf_text_set_content(s$obj, "x"), "Assertion on")
  expect_error(pdf_text_set_render_mode(s$obj, "fill"), "Assertion on")
  expect_error(pdf_text_set_font_size(s$obj, 10), "Assertion on")
})

# Closed-handle protection -------------------------------------------

test_that("setters refuse a closed page handle", {
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  paths <- objs[vapply(objs, function(o) o$type == "path", logical(1L))]
  p <- paths[[1L]]
  pdf_page_close(page)
  expect_error(pdf_obj_set_active(p, FALSE),
               "Parent page has been closed")
})
