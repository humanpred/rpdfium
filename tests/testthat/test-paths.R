test_that("pdf_path_segments validates inputs and refuses non-path objects", {
  expect_error(pdf_path_segments("not an obj"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  text_obj <- Filter(function(o) o$type == "text", objs)[[1]]
  expect_error(
    pdf_path_segments(text_obj),
    "Must be element of set .'path'."
  )
})

test_that("pdf_path_segments refuses objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  path_obj <- Filter(
    function(o) o$type == "path",
    pdf_page_objects(page)
  )[[1]]
  pdf_page_close(page)
  expect_error(
    pdf_path_segments(path_obj),
    "Parent page has been closed"
  )
})

test_that("pdf_path_segments returns a tibble with the documented schema", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  expect_gte(length(paths), 3L) # rect + 2 line segments at minimum

  segs <- pdf_path_segments(paths[[1]])
  expect_s3_class(segs, "tbl_df")
  expect_named(segs, c(
    "segment_index", "segment_type", "x", "y",
    "close_figure", "cx1", "cy1", "cx2", "cy2"
  ))
  expect_type(segs$segment_index, "integer")
  expect_type(segs$segment_type, "character")
  expect_type(segs$x, "double")
  expect_type(segs$y, "double")
  expect_type(segs$close_figure, "logical")
  expect_identical(segs$segment_index, seq_len(nrow(segs)))
  expect_true(all(segs$segment_type %in%
    c("moveto", "lineto", "bezierto", "unknown")))
  # The fixture's rectangle has no curves.
  expect_true(all(is.na(c(segs$cx1, segs$cy1, segs$cx2, segs$cy2))))
})

test_that("pdf_path_segments puts each cubic's control points on its endpoint", {
  doc <- pdf_doc_open(source = inline_curves_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  segs <- pdf_path_segments(pdf_page_objects(doc)[[1L]])
  # One moveto, then a (control 1, control 2, endpoint) triplet per
  # curve.
  expect_identical(segs$segment_type, c("moveto", rep("bezierto", 9L)))
  expect_equal(segs$x[2:4], c(20, 40, 60))
  ends <- segs[!is.na(segs$cx1), ]
  expect_identical(ends$segment_index, c(4L, 7L, 10L))
  expect_equal(ends$x, c(60, 100, 140))
  expect_equal(ends$y, c(70, 110, 150))
  # `c` gives both control points; `v` reuses the current point
  # (60, 70) as the first; `y` reuses the endpoint as the second.
  expect_equal(ends$cx1, c(20, 60, 120))
  expect_equal(ends$cy1, c(30, 70, 130))
  expect_equal(ends$cx2, c(40, 80, 140))
  expect_equal(ends$cy2, c(50, 90, 150))
  # Control-point rows and the moveto carry no control points.
  expect_true(all(is.na(segs$cx2[-c(4L, 7L, 10L)])))
})

test_that("rectangle path matches expected M / L / L / L / L+close pattern", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # The user-drawn rectangle is the second path object (after Cairo's
  # page-bounds path at index 1). graphics::rect emits a closed loop:
  # moveto + 4 linetos with close=TRUE on the last segment.
  rect <- paths[[2]]
  segs <- pdf_path_segments(rect)
  expect_equal(nrow(segs), 5L)
  expect_identical(segs$segment_type[[1]], "moveto")
  expect_true(all(segs$segment_type[-1] == "lineto"))
  expect_true(segs$close_figure[nrow(segs)])
  expect_false(any(segs$close_figure[-nrow(segs)]))

  # The rectangle should close at the same point it started.
  expect_equal(segs$x[[1]], segs$x[[nrow(segs)]], tolerance = 1e-6)
  expect_equal(segs$y[[1]], segs$y[[nrow(segs)]], tolerance = 1e-6)
})

test_that("simple line segment path is M + L (no close)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  line <- paths[[3]] # first diagonal line segment
  segs <- pdf_path_segments(line)
  expect_equal(nrow(segs), 2L)
  expect_identical(segs$segment_type, c("moveto", "lineto"))
  expect_false(any(segs$close_figure))
})

test_that("unknown segment type codes map to 'unknown' safely", {
  expect_identical(pdfium:::pdfium_segment_type_name(-1L), "unknown")
  expect_identical(pdfium:::pdfium_segment_type_name(99L), "unknown")
  expect_identical(pdfium:::pdfium_segment_type_name(0L), "lineto")
  expect_identical(pdfium:::pdfium_segment_type_name(1L), "bezierto")
  expect_identical(pdfium:::pdfium_segment_type_name(2L), "moveto")
  expect_identical(
    pdfium:::pdfium_segment_type_name(c(0L, 1L, 2L, -1L, 5L)),
    c("lineto", "bezierto", "moveto", "unknown", "unknown")
  )
})

test_that("cpp_path_segment_count is exposed at C++ level (test exists for cov)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  rect <- paths[[2]]
  expect_equal(
    pdfium:::cpp_path_segment_count(rect$ptr),
    nrow(pdf_path_segments(rect))
  )
})
