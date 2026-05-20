# Tests for pdf_obj_matrix and pdf_path_dash.

test_that("pdf_obj_matrix returns a 3x3 homogeneous transform matrix", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  for (o in pdf_page_objects(page)) {
    M <- pdf_obj_matrix(o)
    expect_true(is.matrix(M))
    expect_equal(dim(M), c(3L, 3L))
    expect_type(M, "double")
    # Bottom row of the homogeneous form is always (0, 0, 1).
    expect_equal(M[3L, ], c(0, 0, 1))
    expect_false(any(is.na(M)))
  }
})

test_that("Cairo's y-flip matrix is consistent across paths in shapes.pdf", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # Cairo emits PDF paths with a y-flip CTM that maps top-left-origin
  # user space to PDF's bottom-left-origin: a=1, b=0, c=0, d=-1,
  # e=0, f=page_height. Page height for shapes.pdf is 3 in = 216 pt.
  # In the 3x3 homogeneous form this is:
  #   | 1  0  0 |
  #   | 0 -1 216|
  #   | 0  0  1 |
  expected <- matrix(
    c(
      1, 0, 0,
      0, -1, 216,
      0, 0, 1
    ),
    nrow = 3, byrow = TRUE
  )
  for (p in paths) {
    expect_equal(pdf_obj_matrix(p), expected, tolerance = 1e-3)
  }
})

test_that("pdf_obj_matrix transforms points via M %*% c(x, y, 1)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # Y-flip with translation 216: (10, 50) in local coords maps to
  # (10, 216 - 50) = (10, 166) on the page.
  M <- pdf_obj_matrix(paths[[1L]])
  pt <- M %*% c(10, 50, 1)
  expect_equal(pt[1L, 1L], 10, tolerance = 1e-3)
  expect_equal(pt[2L, 1L], 166, tolerance = 1e-3)
  expect_equal(pt[3L, 1L], 1, tolerance = 1e-6)
})

test_that("text object matrix encodes the rendered font size on the diagonal", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  M <- pdf_obj_matrix(text_obj)

  # cex = 1.2 in the fixture; Cairo applies 1.2 * default 12pt =
  # 14.4 to both x- and y-scale and stores it on the matrix
  # diagonal. In the 3x3 homogeneous form, M[1,1] = a, M[2,2] = d.
  expect_equal(M[1L, 1L], 14.4, tolerance = 1e-2)
  expect_equal(M[2L, 2L], 14.4, tolerance = 1e-2)
  # No rotation or skew: M[2,1] = b, M[1,2] = c (both 0).
  expect_equal(M[2L, 1L], 0, tolerance = 1e-6)
  expect_equal(M[1L, 2L], 0, tolerance = 1e-6)
  # Translation column: M[1,3] = e, M[2,3] = f.
  expect_gt(M[1L, 3L], 0)
  expect_gt(M[2L, 3L], 0)
})

test_that("pdf_obj_matrix validates inputs and closed-page state", {
  expect_error(pdf_obj_matrix("nope"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  obj <- pdf_page_objects(page)[[1]]
  pdf_page_close(page)
  expect_error(pdf_obj_matrix(obj), "Parent page has been closed")
})

test_that("pdf_path_dash returns empty array for solid lines", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  # The user-drawn rect and the first diagonal line are solid (lty
  # default). dash$array should be length-0, phase 0.
  for (idx in c(2L, 3L)) { # skip Cairo page-bounds at index 1
    d <- pdf_path_dash(paths[[idx]])
    expect_named(d, c("array", "phase"))
    expect_type(d$array, "double")
    expect_length(d$array, 0L)
    expect_equal(d$phase, 0, tolerance = 1e-6)
  }
})

test_that("pdf_path_dash returns non-empty array for the dashed line", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

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
  expect_error(pdf_path_dash("nope"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  expect_error(
    pdf_path_dash(text_obj),
    "Must be element of set .'path'."
  )
})
