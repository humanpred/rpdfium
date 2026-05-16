# Tests for pdf_annotations(). annotated.pdf is a hand-built
# fixture with four annotations on page 1:
#   1. text     /Rect [20 250 40 270]  /Contents="Hello" /T="Alice"
#   2. highlight /Rect [50 200 200 220]
#   3. link     /Rect [50 150 200 170]  (URI -> example.com)
#   4. widget   /Rect [50 100 200 120]  (form text field, name="name")

test_that("pdf_annotations returns 0 rows for a page with no annots", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  res <- pdf_annotations(page)
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c("annotation_index", "subtype", "flags",
                      "bounds_left", "bounds_bottom",
                      "bounds_right", "bounds_top",
                      "contents", "title"))
})

test_that("pdf_annotations enumerates the four documented annots", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  res <- pdf_annotations(doc, page_num = 1L)
  expect_equal(nrow(res), 4L)
  expect_identical(res$annotation_index, 1L:4L)
  expect_identical(res$subtype,
                   c("text", "highlight", "link", "widget"))
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
