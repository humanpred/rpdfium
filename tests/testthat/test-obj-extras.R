# Tests for the small additional page-object read accessors.

test_that("pdf_path_line_cap / line_join return human-readable strings", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(p))
  skip_if(length(paths) == 0L, "no path objects on shapes.pdf")

  caps <- vapply(paths, pdf_path_line_cap, character(1L))
  joins <- vapply(paths, pdf_path_line_join, character(1L))
  expect_true(all(caps %in% c("butt", "round", "projecting_square")))
  expect_true(all(joins %in% c("miter", "round", "bevel")))
})

test_that("pdf_path_line_cap / line_join reject non-path objects", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  texts <- Filter(function(o) o$type == "text", pdf_page_objects(p))
  skip_if(length(texts) == 0L, "no text objects on shapes.pdf")

  expect_error(pdf_path_line_cap(texts[[1L]]), "Must be element of set")
  expect_error(pdf_path_line_join(texts[[1L]]), "Must be element of set")
})

test_that("pdf_obj_has_transparency returns a logical scalar", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

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
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(p)
  skip_if(length(objs) == 0L, "no page objects")
  states <- vapply(objs, pdf_obj_is_active, logical(1L))
  expect_true(all(states))
})

test_that("pdf_obj_rotated_bounds returns 8 named coordinates", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  texts <- Filter(function(o) o$type == "text", pdf_page_objects(p))
  skip_if(length(texts) == 0L, "no text objects on shapes.pdf")
  q <- pdf_obj_rotated_bounds(texts[[1L]])
  expect_length(q, 8L)
  expect_named(q, c("x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4"))
  expect_true(all(is.finite(q)))
})

test_that("the new accessors all reject bad inputs", {
  for (fn in list(
    pdf_path_line_cap, pdf_path_line_join,
    pdf_obj_has_transparency, pdf_obj_is_active,
    pdf_obj_rotated_bounds
  )) {
    expect_error(fn("not an obj"), "class .pdfium_obj.")
    expect_error(fn(NULL), "class .pdfium_obj.")
  }
})

test_that("pdf_path_draw_mode classifies stroke / fill / clip-only paths", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  paths <- Filter(function(o) o$type == "path", pdf_page_objects(p))
  expect_gt(length(paths), 0L)
  for (path_obj in paths) {
    m <- pdf_path_draw_mode(path_obj)
    expect_named(m, c("fill_mode", "fill_mode_code", "stroke"))
    expect_true(m$fill_mode %in%
      c("none", "even_odd", "winding", NA_character_))
    expect_true(m$fill_mode_code %in% c(0L, 1L, 2L, NA_integer_))
    expect_true(is.logical(m$stroke) && length(m$stroke) == 1L)
  }
  # shapes.pdf carries at least one path that is both filled
  # (winding) and stroked.
  modes <- vapply(
    paths, function(o) pdf_path_draw_mode(o)$fill_mode,
    character(1L)
  )
  strokes <- vapply(
    paths, function(o) pdf_path_draw_mode(o)$stroke,
    logical(1L)
  )
  expect_true(any(modes == "winding" & strokes))
})

test_that("pdf_path_draw_mode rejects non-path objects and closed pages", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(p)
  path_obj <- Filter(function(o) o$type == "path", objs)[[1L]]
  expect_error(pdf_path_draw_mode("nope"), "class .pdfium_obj.")
  pdf_page_close(p)
  expect_error(
    pdf_path_draw_mode(path_obj),
    "Parent page has been closed"
  )
})

test_that("pdf_obj_marks returns an empty tibble for untagged content", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  for (obj in pdf_page_objects(p)) {
    res <- pdf_obj_marks(obj)
    expect_s3_class(res, "tbl_df")
    expect_equal(nrow(res), 0L)
    expect_named(res, c("mark_index", "name", "params"))
  }
})

test_that("pdf_obj_marks surfaces BDC tags on tagged content", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(p)
  expect_gte(length(objs), 1L)
  marks <- pdf_obj_marks(objs[[1L]])
  expect_s3_class(marks, "tbl_df")
  expect_equal(nrow(marks), 1L)
  expect_equal(marks$name[[1L]], "P")
  expect_equal(marks$params[[1L]]$MCID, 0L)
})

test_that("pdf_obj_marked_content_id reads the direct MCID", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  obj <- pdf_page_objects(p)[[1L]]
  expect_equal(pdf_obj_marked_content_id(obj), 0L)
})

test_that("pdf_obj_marks rejects non-objects and closed parents", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  obj <- pdf_page_objects(p)[[1L]]
  expect_error(pdf_obj_marks("nope"), "class .pdfium_obj.")
  pdf_page_close(p)
  expect_error(pdf_obj_marks(obj), "Parent page has been closed")
})

test_that("accessors refuse a closed parent page", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(p)
  skip_if(length(objs) == 0L, "no page objects")
  pdf_page_close(p)

  expect_error(
    pdf_obj_has_transparency(objs[[1L]]),
    "Parent page has been closed"
  )
  expect_error(
    pdf_obj_is_active(objs[[1L]]),
    "Parent page has been closed"
  )
  expect_error(
    pdf_obj_rotated_bounds(objs[[1L]]),
    "Parent page has been closed"
  )
})

# Rendered pattern tiles ----------------------------------------------

# A 96 x 96 pt page. Object 1 fills the bottom half with an 8 x 4
# tiling pattern whose cell has a blue 2 x 2 square at its bottom-left
# and a red bar along its top edge. Object 2 is a rectangle filled
# plain green and stroked with the same pattern.
pattern_pdf <- function() {
  inline_pdf_bytes(c(  # nolint: object_usage_linter.
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 96 96] ",
           "/Contents 4 0 R /Resources << /Pattern << /P1 5 0 R >> >> >>"),
    inline_pdf_stream("", paste(  # nolint: object_usage_linter.
      "q /Pattern cs /P1 scn 0 0 96 48 re f Q",
      "q 0 1 0 rg /Pattern CS /P1 SCN 4 w 8 56 80 32 re B Q"
    )),
    inline_pdf_stream(
      paste("/Type /Pattern /PatternType 1 /PaintType 1 /TilingType 1",
            "/BBox [0 0 8 4] /XStep 8 /YStep 4 /Resources << >>"),
      "0 0 1 rg 0 0 2 2 re f 1 0 0 rg 0 3 8 1 re f"
    )
  ))
}

red_mask <- function(rgba) rgba[, , 1L] > 0.9 & rgba[, , 3L] < 0.1
blue_mask <- function(rgba) rgba[, , 3L] > 0.9 & rgba[, , 1L] < 0.1

test_that("pdf_obj_rendered_fill_pattern returns one tile, top row first", {
  doc <- pdf_doc_open(source = pattern_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  objs <- pdf_page_objects(doc)
  tile <- pdf_obj_rendered_fill_pattern(objs[[1L]])
  expect_s3_class(tile, "pdfium_bitmap")
  expect_identical(dim(tile), c(4L, 8L))
  expect_identical(attr(tile, "source_page"), 1L)
  rgba <- as.array(tile)
  # The cell's top edge (the red bar) is the first row; its
  # bottom-left blue square the last two rows. Unpainted pixels are
  # transparent.
  expect_true(all(red_mask(rgba)[1L, ]))
  expect_true(all(blue_mask(rgba)[3:4, 1:2]))
  expect_identical(sum(red_mask(rgba)), 8L)
  expect_identical(sum(blue_mask(rgba)), 4L)
  expect_identical(sum(rgba[, , 4L] > 0), 12L)
  # Same orientation as the page render: the pattern region's top
  # tile row (page y 44..48) is pixel rows 49..52 at 72 dpi.
  on_page <- as.array(pdf_render_page(doc, dpi = 72))[49:52, 1:8, ]
  expect_identical(red_mask(on_page), red_mask(rgba))
  expect_identical(blue_mask(on_page), blue_mask(rgba))
})

test_that("pattern tiles are NULL when the colour is not a pattern", {
  doc <- pdf_doc_open(source = pattern_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  objs <- pdf_page_objects(doc)
  # Object 1's stroke colour is the default black; object 2's fill is
  # plain green, and its stroke carries the pattern.
  expect_null(pdf_obj_rendered_stroke_pattern(objs[[1L]]))
  expect_null(pdf_obj_rendered_fill_pattern(objs[[2L]]))
  stroke_tile <- pdf_obj_rendered_stroke_pattern(objs[[2L]])
  expect_identical(as.integer(stroke_tile),
                   as.integer(pdf_obj_rendered_fill_pattern(objs[[1L]])))
  shapes <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(shapes), add = TRUE)
  expect_null(pdf_obj_rendered_fill_pattern(pdf_page_objects(shapes)[[1L]]))
})

test_that("pattern tile readers refuse bad input and closed pages", {
  expect_error(pdf_obj_rendered_fill_pattern("nope"),
               "class .pdfium_obj.")
  doc <- pdf_doc_open(source = pattern_pdf())
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  obj <- pdf_page_objects(p)[[1L]]
  pdf_page_close(p)
  expect_error(pdf_obj_rendered_fill_pattern(obj),
               "Parent page has been closed")
  expect_error(pdf_obj_rendered_stroke_pattern(obj),
               "Parent page has been closed")
})
