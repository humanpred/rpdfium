# Tests for pdf_annotations(). annotated.pdf is a hand-built
# fixture with five annotations on page 1:
#   1. text     /Rect [20 250 40 270]  /Contents="Hello" /T="Alice"
#   2. highlight /Rect [50 200 200 220]
#   3. link     /Rect [50 150 200 170]  (URI -> example.com)
#   4. widget   /Rect [50 100 200 120]  (form text field, name="name")
#   5. widget   /Rect [50  60  70  80]  (form checkbox,  name="agree")

test_that("pdf_annotations returns 0 rows for a page with no annots", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  res <- pdf_annotations(page)
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c("annotation_index", "subtype_code", "subtype",
                      "flags", "is_invisible", "is_hidden", "is_print",
                      "is_no_view", "is_read_only", "is_locked",
                      "bounds_left", "bounds_bottom",
                      "bounds_right", "bounds_top",
                      "contents", "title", "subject",
                      "color_red", "color_green", "color_blue",
                      "color_alpha", "interior_red", "interior_green",
                      "interior_blue", "interior_alpha",
                      "border_width",
                      "quad_points", "vertices", "ink_paths"))
})

test_that("pdf_annotations populates quad_points / vertices / ink_paths", {
  res <- pdf_annotations(pdf_open(fixture_path("annot_geom")),
                         page_num = 1L)
  expect_equal(nrow(res), 3L)
  # The polygon row has /Vertices but no quads or ink.
  poly <- res[res$subtype == "polygon", ]
  expect_equal(nrow(poly), 1L)
  expect_true(is.null(poly$quad_points[[1L]]))
  expect_true(is.null(poly$ink_paths[[1L]]))
  v <- poly$vertices[[1L]]
  expect_true(is.matrix(v))
  expect_equal(dim(v), c(3L, 2L))
  expect_equal(v[1L, ], c(x = 10, y = 10))
  expect_equal(v[2L, ], c(x = 60, y = 10))
  expect_equal(v[3L, ], c(x = 35, y = 60))

  # The ink row has /InkList with two strokes.
  ink <- res[res$subtype == "ink", ]
  expect_true(is.null(ink$quad_points[[1L]]))
  expect_true(is.null(ink$vertices[[1L]]))
  paths <- ink$ink_paths[[1L]]
  expect_type(paths, "list")
  expect_length(paths, 2L)
  expect_equal(dim(paths[[1L]]), c(3L, 2L))
  expect_equal(dim(paths[[2L]]), c(2L, 2L))
  expect_equal(paths[[2L]][1L, ], c(x = 120, y = 180))

  # The two-line highlight has /QuadPoints with two quad sets.
  hl <- res[res$subtype == "highlight", ]
  expect_true(is.null(hl$vertices[[1L]]))
  expect_true(is.null(hl$ink_paths[[1L]]))
  q <- hl$quad_points[[1L]]
  expect_true(is.matrix(q))
  expect_equal(dim(q), c(2L, 8L))
  expect_equal(colnames(q),
               c("x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4"))
  expect_equal(q[1L, ],
               c(x1 = 50, y1 = 290, x2 = 250, y2 = 290,
                 x3 = 50, y3 = 270, x4 = 250, y4 = 270))
})

test_that("pdfium_annot_subtype_code round-trips with the name helper", {
  codes <- 0L:9L
  names <- pdfium:::annotation_subtype_name(codes)
  back  <- pdfium:::pdfium_annot_subtype_code(names)
  expect_identical(back, codes)
  # Unknown / NA -> 0L (UNKNOWN).
  expect_identical(pdfium:::pdfium_annot_subtype_code(c("bogus", NA)),
                   c(0L, 0L))
})

test_that("pdf_annotations reads color and subject when set", {
  res <- pdf_annotations(pdf_open(fixture_path("annotated")),
                         page_num = 1L)
  # Highlight annot (annotation_index 2) carries /C [0.9 0.9 0.2]
  # and /Subj (Important) per the fixture.
  hl <- res[res$subtype == "highlight", ]
  expect_equal(nrow(hl), 1L)
  expect_equal(hl$color_red[[1L]],   229 / 255, tolerance = 1e-3)
  expect_equal(hl$color_green[[1L]], 229 / 255, tolerance = 1e-3)
  expect_equal(hl$color_blue[[1L]],   51 / 255, tolerance = 1e-3)
  expect_equal(hl$color_alpha[[1L]], 1.0)
  expect_equal(hl$subject[[1L]],     "Important")
  # Annots without /C come back as NA (no fallback to appearance
  # stream — see read_annot_color in src/annotations.cpp).
  txt <- res[res$subtype == "text", ]
  expect_true(is.na(txt$color_red[[1L]]))
  expect_true(is.na(txt$color_alpha[[1L]]))
})

test_that("pdf_annotations decodes the universal /F flag bits", {
  # Bits 1, 2, 3, 6, 7, 8 decode independently; annotated.pdf has
  # no /F set on any annot so all flags should be FALSE.
  res <- pdf_annotations(pdf_open(fixture_path("annotated")),
                         page_num = 1L)
  expect_true(all(!res$is_invisible))
  expect_true(all(!res$is_hidden))
  expect_true(all(!res$is_print))
  expect_true(all(!res$is_no_view))
  expect_true(all(!res$is_read_only))
  expect_true(all(!res$is_locked))
  # Direct unit-test the decoder so a single fixture doesn't have
  # to cover every bit.
  expect_identical(
    pdfium:::annot_flag_decode(c(0L, 1L, 4L, 64L, 128L), 1L),
    c(FALSE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_identical(
    pdfium:::annot_flag_decode(c(0L, 1L, 4L, 64L, 128L), 3L),
    c(FALSE, FALSE, TRUE, FALSE, FALSE)
  )
  expect_identical(
    pdfium:::annot_flag_decode(c(0L, 1L, 4L, 64L, 128L), 8L),
    c(FALSE, FALSE, FALSE, FALSE, TRUE)
  )
})

test_that("pdf_annotations enumerates the documented annots", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  res <- pdf_annotations(doc, page_num = 1L)
  expect_equal(nrow(res), 5L)
  expect_identical(res$annotation_index, 1L:5L)
  expect_identical(res$subtype,
                   c("text", "highlight", "link", "widget", "widget"))
})

test_that("pdf_annotations surfaces the text annotation's strings", {
  res <- pdf_annotations(pdf_open(fixture_path("annotated")),
                         page_num = 1L)
  expect_identical(res$contents[[1L]], "Hello")
  expect_identical(res$title[[1L]],    "Alice")
})

test_that("pdf_annotations reads the rectangles", {
  res <- pdf_annotations(pdf_open(fixture_path("annotated")),
                         page_num = 1L)
  expect_equal(res$bounds_left[[1L]],   20)
  expect_equal(res$bounds_bottom[[1L]], 250)
  expect_equal(res$bounds_right[[1L]],  40)
  expect_equal(res$bounds_top[[1L]],    270)
  expect_equal(res$bounds_left[[3L]],   50)   # link
  expect_equal(res$bounds_right[[3L]],  200)
})

test_that("pdf_annotations accepts an open page directly", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  by_page <- pdf_annotations(page)
  by_doc  <- pdf_annotations(doc, page_num = 1L)
  expect_identical(by_page, by_doc)
})

test_that("pdf_annotations rejects bad inputs", {
  expect_error(pdf_annotations("not a page"),
               "must be a `pdfium_page` or a `pdfium_doc`")
  expect_error(pdf_annotations(42),
               "must be a `pdfium_page` or a `pdfium_doc`")
})

test_that("pdf_annotations refuses a closed page handle", {
  doc <- pdf_open(fixture_path("annotated"))
  page <- pdf_load_page(doc, 1L)
  pdf_close_page(page)
  expect_error(pdf_annotations(page), "Page has been closed")
  pdf_close(doc)
})

test_that("annotation_subtype_name maps codes to documented strings", {
  expect_identical(
    pdfium:::annotation_subtype_name(0L:9L),
    c("unknown", "text", "link", "freetext", "line", "square",
      "circle", "polygon", "polyline", "highlight")
  )
  # Out-of-range codes fall through to "unknown".
  expect_identical(pdfium:::annotation_subtype_name(99L), "unknown")
  expect_identical(pdfium:::annotation_subtype_name(-1L), "unknown")
  expect_identical(pdfium:::annotation_subtype_name(NA_integer_),
                   "unknown")
})
