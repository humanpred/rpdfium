# Tests for pdf_obj_matrix and pdf_path_dash.

test_that("pdf_obj_matrix returns the documented length-6 named vector", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  for (o in pdf_page_objects(page)) {
    m <- pdf_obj_matrix(o)
    expect_type(m, "double")
    expect_named(m, c("a", "b", "c", "d", "e", "f"))
    expect_false(any(is.na(m)))
  }
})

test_that("Cairo's y-flip matrix is consistent across paths in shapes.pdf", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # Cairo emits PDF paths with a y-flip CTM that maps top-left-origin
  # user space to PDF's bottom-left-origin: a=1, b=0, c=0, d=-1,
  # e=0, f=page_height. Page height for shapes.pdf is 3 in = 216 pt.
  for (p in paths) {
    m <- pdf_obj_matrix(p)
    expect_equal(unname(m), c(1, 0, 0, -1, 0, 216), tolerance = 1e-3)
  }
})

test_that("text object matrix encodes the rendered font size in (a, d)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  text_obj <- Filter(function(o) o$type == "text",
                     pdf_page_objects(page))[[1]]
  m <- pdf_obj_matrix(text_obj)

  # cex = 1.2 in the fixture; Cairo applies 1.2 * default 12pt =
  # 14.4 to both x- and y-scale and encodes it in the matrix. The
  # raw font size from pdf_text_font_size() is 1; the visible size
  # is matrix$a (== matrix$d).
  expect_equal(m[["a"]], 14.4, tolerance = 1e-2)
  expect_equal(m[["d"]], 14.4, tolerance = 1e-2)
  # No rotation or skew on the text.
  expect_equal(m[["b"]], 0, tolerance = 1e-6)
  expect_equal(m[["c"]], 0, tolerance = 1e-6)
  # Translation = position of the text on the page.
  expect_gt(m[["e"]], 0)
  expect_gt(m[["f"]], 0)
})

test_that("pdf_obj_matrix validates inputs and closed-page state", {
  expect_error(pdf_obj_matrix("nope"), "must be a `pdfium_obj`")

  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  obj <- pdf_page_objects(page)[[1]]
  pdf_close_page(page)
  expect_error(pdf_obj_matrix(obj), "Parent page has been closed")
})

test_that("pdf_path_dash returns empty array for solid lines", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # The user-drawn rect and the first diagonal line are solid (lty
  # default). dash$array should be length-0, phase 0.
  for (idx in c(2L, 3L)) {  # skip Cairo page-bounds at index 1
    d <- pdf_path_dash(paths[[idx]])
    expect_named(d, c("array", "phase"))
    expect_type(d$array, "double")
    expect_length(d$array, 0L)
    expect_equal(d$phase, 0, tolerance = 1e-6)
  }
})

test_that("pdf_path_dash returns non-empty array for the dashed line", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # Path 4 is the second diagonal segment, drawn with lty = "dashed".
  # Cairo encodes "dashed" as c(4.5, 4.5) (on, off).
  d <- pdf_path_dash(paths[[4]])
  expect_length(d$array, 2L)
  expect_true(all(d$array > 0))
  expect_equal(d$array, c(4.5, 4.5), tolerance = 1e-3)
  expect_equal(d$phase, 0, tolerance = 1e-6)
})

test_that("pdf_path_dash refuses non-path objects and closed pages", {
  expect_error(pdf_path_dash("nope"), "must be a `pdfium_obj`")

  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  text_obj <- Filter(function(o) o$type == "text",
                     pdf_page_objects(page))[[1]]
  expect_error(pdf_path_dash(text_obj),
               "must be a path-type pdfium_obj.*\"text\"")
})
