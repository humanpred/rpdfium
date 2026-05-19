# Tests for pdf_path_stroke / pdf_path_fill / pdf_text_font_size.

test_that("pdf_path_stroke / _fill validate inputs and refuse non-path objs", {
  expect_error(pdf_path_stroke("nope"), "class .pdfium_obj.")
  expect_error(pdf_path_fill("nope"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  text_obj <- Filter(function(o) o$type == "text", pdf_page_objects(page))[[1]]
  expect_error(
    pdf_path_stroke(text_obj),
    "Must be element of set .'path'."
  )
  expect_error(
    pdf_path_fill(text_obj),
    "Must be element of set .'path'."
  )
})

test_that("pdf_path_stroke / _fill refuse objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  path_obj <- Filter(
    function(o) o$type == "path",
    pdf_page_objects(page)
  )[[1]]
  pdf_close_page(page)
  expect_error(pdf_path_stroke(path_obj), "Parent page has been closed")
  expect_error(pdf_path_fill(path_obj), "Parent page has been closed")
})

test_that("pdf_path_stroke returns the expected shape", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  s <- pdf_path_stroke(paths[[2]]) # the user-drawn rectangle
  expect_named(s, c("red", "green", "blue", "alpha", "width"))
  expect_type(s, "double")
  channels <- s[c("red", "green", "blue", "alpha")]
  expect_true(all(channels >= 0 & channels <= 255, na.rm = TRUE))
})

test_that("rectangle stroke is red (border = 'red'), fill is lightblue", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  rect <- paths[[2]]
  stroke <- pdf_path_stroke(rect)
  expect_named(stroke, c("red", "green", "blue", "alpha", "width"))
  expect_equal(unname(stroke[c("red", "green", "blue", "alpha")]),
    c(255, 0, 0, 255),
    tolerance = 0
  )
  expect_gt(stroke[["width"]], 0)

  fill <- pdf_path_fill(rect)
  # R's "lightblue" -> hex #ADD8E6 -> (173, 216, 230)
  expect_equal(unname(fill),
    c(173, 216, 230, 255),
    tolerance = 0
  )
})

test_that("diagonal line stroke is darkgreen, no fill set or fill carries default", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  line <- paths[[3]] # first diagonal line segment
  stroke <- pdf_path_stroke(line)
  # R's "darkgreen" -> #006400 -> (0, 100, 0)
  expect_equal(unname(stroke[c("red", "green", "blue", "alpha")]),
    c(0, 100, 0, 255),
    tolerance = 0
  )
  expect_gt(stroke[["width"]], 0)
})

test_that("pdf_text_font_size returns a numeric scalar for text objs", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  size <- pdf_text_font_size(text_obj)
  expect_type(size, "double")
  expect_length(size, 1L)
  # Cairo emits text at em-size 1 and scales via CTM, so the
  # PDFium-reported font size is 1 (NOT the rendered 1.2 * 12 = 14.4
  # we'd expect from cex). This is documented in @details.
  expect_equal(size, 1, tolerance = 1e-6)
})

test_that("pdf_text_font_size validates input and refuses non-text objects", {
  expect_error(pdf_text_font_size("nope"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  path_obj <- Filter(
    function(o) o$type == "path",
    pdf_page_objects(page)
  )[[1]]
  expect_error(
    pdf_text_font_size(path_obj),
    "Must be element of set"
  )
})

test_that("pdf_text_font_size refuses objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  pdf_close_page(page)
  expect_error(
    pdf_text_font_size(text_obj),
    "Parent page has been closed"
  )
})
