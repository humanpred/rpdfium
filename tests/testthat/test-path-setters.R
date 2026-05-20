# Tests for the Phase 4 path-geometry appenders. Each test loads
# shapes.pdf readwrite, takes its first path object, appends new
# segments, and verifies the reader sees them. The doc's dirty-
# pages set should track every mutation so pdf_save() flushes it.

# Helper: open shapes.pdf readwrite + load first path obj. Mirrors
# the setters_first_path() helper in test-obj-setters.R; defined
# locally here so each test file stays self-contained.
phase4_first_path <- function(envir = parent.frame()) {
  # `fixture_path()` lives in helper-fixtures.R; lintr can't see it
  # from this helper's body so suppress the false positive.
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)  # nolint
  withr::defer(pdf_doc_close(doc), envir = envir)
  page <- pdf_page_load(doc, 1L)
  withr::defer(pdf_page_close(page), envir = envir,
                priority = "first")
  objs <- pdf_page_objects(page)
  types <- vapply(objs, function(o) o$type, character(1L))
  path <- objs[types == "path"][[1L]]
  list(doc = doc, page = page, obj = path)
}

# Atomic appenders ----------------------------------------------------

test_that("pdf_path_move_to appends and marks dirty", {
  s <- phase4_first_path()
  before <- nrow(pdf_path_segments(s$obj))
  ret <- pdf_path_move_to(s$obj, 10, 20)
  expect_identical(ret, s$doc)
  expect_setequal(s$doc$state$dirty_pages, 1L)

  after <- pdf_path_segments(s$obj)
  expect_equal(nrow(after), before + 1L)
  last <- after[nrow(after), ]
  expect_identical(last$segment_type, "moveto")
  expect_equal(last$x, 10)
  expect_equal(last$y, 20)
})

test_that("pdf_path_line_to appends a lineto", {
  s <- phase4_first_path()
  before <- nrow(pdf_path_segments(s$obj))
  pdf_path_line_to(s$obj, 100, 200)
  after <- pdf_path_segments(s$obj)
  expect_equal(nrow(after), before + 1L)
  last <- after[nrow(after), ]
  expect_identical(last$segment_type, "lineto")
  expect_equal(last$x, 100)
  expect_equal(last$y, 200)
})

test_that("pdf_path_bezier_to appends three bezierto rows", {
  # PDFium's reader surfaces each cubic curve as a triplet of
  # `bezierto` rows: two control points followed by the endpoint.
  s <- phase4_first_path()
  before <- nrow(pdf_path_segments(s$obj))
  pdf_path_bezier_to(s$obj, 1, 2, 3, 4, 5, 6)
  after <- pdf_path_segments(s$obj)
  expect_equal(nrow(after), before + 3L)
  tail3 <- after[(nrow(after) - 2L):nrow(after), ]
  expect_identical(tail3$segment_type,
                   rep("bezierto", 3L))
  expect_equal(tail3$x, c(1, 3, 5))
  expect_equal(tail3$y, c(2, 4, 6))
})

test_that("pdf_path_close marks the previous segment as closed", {
  s <- phase4_first_path()
  pdf_path_move_to(s$obj, 0, 0)
  pdf_path_line_to(s$obj, 10, 0)
  pdf_path_close(s$obj)
  segs <- pdf_path_segments(s$obj)
  # PDFium reports the close flag on the segment immediately before
  # the close (the lineto endpoint).
  expect_true(tail(segs$close_figure, 1L))
})

# Composite pdf_path_append ------------------------------------------

test_that("pdf_path_append replays a moveto/lineto/close triangle", {
  s <- phase4_first_path()
  before <- nrow(pdf_path_segments(s$obj))
  triangle <- tibble::tibble(
    segment_type = c("moveto", "lineto", "lineto", "lineto"),
    x            = c(0, 100, 50, 0),
    y            = c(0, 0, 86, 0),
    close_figure = c(FALSE, FALSE, FALSE, TRUE)
  )
  pdf_path_append(s$obj, triangle)
  after <- pdf_path_segments(s$obj)
  expect_equal(nrow(after), before + nrow(triangle))
  tail_added <- after[(before + 1L):nrow(after), ]
  expect_identical(tail_added$segment_type,
                   triangle$segment_type)
  expect_equal(tail_added$x, triangle$x)
  expect_equal(tail_added$y, triangle$y)
  expect_identical(tail_added$close_figure,
                   triangle$close_figure)
})

test_that("pdf_path_append emits one bezier per triplet", {
  s <- phase4_first_path()
  before <- nrow(pdf_path_segments(s$obj))
  curve <- tibble::tibble(
    segment_type = c("moveto",
                     "bezierto", "bezierto", "bezierto"),
    x            = c(0, 10, 20, 30),
    y            = c(0, 10, 20, 30),
    close_figure = c(FALSE, FALSE, FALSE, FALSE)
  )
  pdf_path_append(s$obj, curve)
  after <- pdf_path_segments(s$obj)
  expect_equal(nrow(after), before + 4L)
  tail4 <- after[(nrow(after) - 3L):nrow(after), ]
  expect_identical(tail4$segment_type,
                   c("moveto", "bezierto", "bezierto", "bezierto"))
})

test_that("pdf_path_append round-trips through pdf_path_segments", {
  s <- phase4_first_path()
  segs <- pdf_path_segments(s$obj)
  # Append the existing segments to themselves; the result should
  # be the original plus an identical copy.
  pdf_path_append(s$obj, segs)
  segs2 <- pdf_path_segments(s$obj)
  expect_equal(nrow(segs2), 2L * nrow(segs))
  half <- segs2[(nrow(segs) + 1L):nrow(segs2),
                c("segment_type", "x", "y", "close_figure")]
  expect_identical(half$segment_type, segs$segment_type)
  expect_equal(half$x, segs$x)
  expect_equal(half$y, segs$y)
  expect_identical(half$close_figure, segs$close_figure)
})

test_that("pdf_path_append catches partial bezier triplets", {
  s <- phase4_first_path()
  bad <- tibble::tibble(
    segment_type = c("moveto", "bezierto", "bezierto"),  # only 2 cp
    x            = c(0, 1, 2),
    y            = c(0, 1, 2)
  )
  expect_error(pdf_path_append(s$obj, bad),
               "Incomplete bezierto triplet")
})

test_that("pdf_path_append rejects unknown segment types", {
  s <- phase4_first_path()
  bad <- tibble::tibble(
    segment_type = c("moveto", "arc"),
    x            = c(0, 1),
    y            = c(0, 1)
  )
  expect_error(pdf_path_append(s$obj, bad),
               "Unknown path segment type")
})

test_that("pdf_path_append rejects a bezierto interrupted by a lineto", {
  s <- phase4_first_path()
  bad <- tibble::tibble(
    segment_type = c("bezierto", "lineto"),  # broken triplet
    x            = c(1, 5),
    y            = c(2, 6)
  )
  expect_error(pdf_path_append(s$obj, bad),
               "Incomplete bezierto triplet")
})

test_that("pdf_path_append rejects a bezierto interrupted by a moveto", {
  s <- phase4_first_path()
  bad <- tibble::tibble(
    segment_type = c("bezierto", "moveto"),  # broken triplet
    x            = c(1, 5),
    y            = c(2, 6)
  )
  expect_error(pdf_path_append(s$obj, bad),
               "Incomplete bezierto triplet")
})

# Input validation ----------------------------------------------------

test_that("appenders validate numeric inputs", {
  s <- phase4_first_path()
  expect_error(pdf_path_move_to(s$obj, NA, 0), "Assertion on")
  expect_error(pdf_path_move_to(s$obj, Inf, 0), "Assertion on")
  expect_error(pdf_path_line_to(s$obj, 0, "y"), "Assertion on")
  expect_error(
    pdf_path_bezier_to(s$obj, 0, 0, 0, 0, NA, 0),
    "Assertion on"
  )
})

test_that("appenders reject non-path objects", {
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  text <- objs[vapply(objs, function(o) o$type == "text",
                       logical(1L))][[1L]]
  expect_error(pdf_path_move_to(text, 0, 0), "Assertion on")
  expect_error(pdf_path_line_to(text, 0, 0), "Assertion on")
  expect_error(pdf_path_bezier_to(text, 0, 0, 0, 0, 0, 0),
               "Assertion on")
  expect_error(pdf_path_close(text), "Assertion on")
})

test_that("appenders refuse a read-only doc", {
  # Default readwrite = FALSE; appenders must trip assert_readwrite.
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  p <- objs[vapply(objs, function(o) o$type == "path",
                    logical(1L))][[1L]]
  expect_error(pdf_path_move_to(p, 0, 0), "readwrite")
  expect_error(pdf_path_line_to(p, 0, 0), "readwrite")
  expect_error(pdf_path_close(p), "readwrite")
})

test_that("appenders refuse a closed-page handle", {
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  p <- objs[vapply(objs, function(o) o$type == "path",
                    logical(1L))][[1L]]
  pdf_page_close(page)
  expect_error(pdf_path_move_to(p, 0, 0),
               "Parent page has been closed")
})
