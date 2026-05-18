# Tests for the small additional page-object read accessors.

test_that("pdf_path_line_cap / line_join return human-readable strings", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(p))
  skip_if(length(paths) == 0L, "no path objects on shapes.pdf")

  caps  <- vapply(paths, pdf_path_line_cap,  character(1L))
  joins <- vapply(paths, pdf_path_line_join, character(1L))
  expect_true(all(caps  %in% c("butt", "round", "projecting_square")))
  expect_true(all(joins %in% c("miter", "round", "bevel")))
})

test_that("pdf_path_line_cap / line_join reject non-path objects", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)

  texts <- Filter(function(o) o$type == "text", pdf_page_objects(p))
  skip_if(length(texts) == 0L, "no text objects on shapes.pdf")

  expect_error(pdf_path_line_cap(texts[[1L]]),  "must be one of")
  expect_error(pdf_path_line_join(texts[[1L]]), "must be one of")
})

test_that("pdf_obj_has_transparency returns a logical scalar", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(p)
  skip_if(length(objs) == 0L, "no page objects")
  for (o in objs) {
    v <- pdf_obj_has_transparency(o)
    expect_type(v, "logical")
    expect_length(v, 1L)
    expect_false(is.na(v))
  }
})

test_that("pdf_obj_is_active is TRUE for objects on a freshly loaded page", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(p)
  skip_if(length(objs) == 0L, "no page objects")
  states <- vapply(objs, pdf_obj_is_active, logical(1L))
  expect_true(all(states))
})

test_that("pdf_obj_rotated_bounds returns 8 named coordinates", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)

  texts <- Filter(function(o) o$type == "text", pdf_page_objects(p))
  skip_if(length(texts) == 0L, "no text objects on shapes.pdf")
  q <- pdf_obj_rotated_bounds(texts[[1L]])
  expect_length(q, 8L)
  expect_named(q, c("x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4"))
  expect_true(all(is.finite(q)))
})

test_that("the new accessors all reject bad inputs", {
  for (fn in list(pdf_path_line_cap, pdf_path_line_join,
                  pdf_obj_has_transparency, pdf_obj_is_active,
                  pdf_obj_rotated_bounds)) {
    expect_error(fn("not an obj"), "must be a `pdfium_obj`")
    expect_error(fn(NULL),         "must be a `pdfium_obj`")
  }
})

test_that("accessors refuse a closed parent page", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  objs <- pdf_page_objects(p)
  skip_if(length(objs) == 0L, "no page objects")
  pdf_close_page(p)

  expect_error(pdf_obj_has_transparency(objs[[1L]]),
               "Parent page has been closed")
  expect_error(pdf_obj_is_active(objs[[1L]]),
               "Parent page has been closed")
  expect_error(pdf_obj_rotated_bounds(objs[[1L]]),
               "Parent page has been closed")
})
