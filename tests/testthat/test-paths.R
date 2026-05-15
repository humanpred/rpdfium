test_that("pdf_path_segments validates inputs and refuses non-path objects", {
  expect_error(pdf_path_segments("not an obj"), "must be a `pdfium_obj`")

  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  text_obj <- Filter(function(o) o$type == "text", objs)[[1]]
  expect_error(pdf_path_segments(text_obj),
               "must be a path-type pdfium_obj.*\"text\"")
})

test_that("pdf_path_segments refuses objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  path_obj <- Filter(function(o) o$type == "path",
                     pdf_page_objects(page))[[1]]
  pdf_close_page(page)
  expect_error(pdf_path_segments(path_obj),
               "Parent page has been closed")
})

test_that("pdf_path_segments returns a tibble with the documented schema", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  expect_gte(length(paths), 3L)  # rect + 2 line segments at minimum

  segs <- pdf_path_segments(paths[[1]])
  expect_s3_class(segs, "tbl_df")
  expect_named(segs, c("index", "type", "x", "y", "close"))
  expect_type(segs$index, "integer")
  expect_type(segs$type,  "character")
  expect_type(segs$x,     "double")
  expect_type(segs$y,     "double")
  expect_type(segs$close, "logical")
  expect_identical(segs$index, seq_len(nrow(segs)))
  expect_true(all(segs$type %in%
                    c("moveto", "lineto", "bezierto", "unknown")))
})

test_that("rectangle path matches expected M / L / L / L / L+close pattern", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # The user-drawn rectangle is the second path object (after Cairo's
  # page-bounds path at index 1). graphics::rect emits a closed loop:
  # moveto + 4 linetos with close=TRUE on the last segment.
  rect <- paths[[2]]
  segs <- pdf_path_segments(rect)
  expect_equal(nrow(segs), 5L)
  expect_identical(segs$type[[1]], "moveto")
  expect_true(all(segs$type[-1] == "lineto"))
  expect_true(segs$close[nrow(segs)])
  expect_false(any(segs$close[-nrow(segs)]))

  # The rectangle should close at the same point it started.
  expect_equal(segs$x[[1]], segs$x[[nrow(segs)]], tolerance = 1e-6)
  expect_equal(segs$y[[1]], segs$y[[nrow(segs)]], tolerance = 1e-6)
})

test_that("simple line segment path is M + L (no close)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  line <- paths[[3]]  # first diagonal line segment
  segs <- pdf_path_segments(line)
  expect_equal(nrow(segs), 2L)
  expect_identical(segs$type, c("moveto", "lineto"))
  expect_false(any(segs$close))
})

test_that("unknown segment type codes map to 'unknown' safely", {
  expect_identical(pdfium:::pdfium_segment_type_name(-1L),    "unknown")
  expect_identical(pdfium:::pdfium_segment_type_name(99L),    "unknown")
  expect_identical(pdfium:::pdfium_segment_type_name(0L),     "lineto")
  expect_identical(pdfium:::pdfium_segment_type_name(1L),     "bezierto")
  expect_identical(pdfium:::pdfium_segment_type_name(2L),     "moveto")
  expect_identical(pdfium:::pdfium_segment_type_name(c(0L, 1L, 2L, -1L, 5L)),
                   c("lineto", "bezierto", "moveto", "unknown", "unknown"))
})

test_that("cpp_path_segment_count is exposed at C++ level (test exists for cov)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  rect <- paths[[2]]
  expect_equal(pdfium:::cpp_path_segment_count(rect$ptr),
               nrow(pdf_path_segments(rect)))
})
