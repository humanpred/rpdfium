# Tests for the page-level navigation extras: pdf_link_at_point()
# and pdf_page_actions().

test_that("pdf_link_at_point reports the URI link in annotated.pdf", {
  # annotated.pdf has a link annotation at rect (50, 150)-(200, 170)
  # whose URI action targets https://example.com.
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)

  out <- pdf_link_at_point(p, x = 125, y = 160)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  expect_equal(out$action_type, "uri")
  expect_equal(out$uri, "https://example.com")
  expect_true(is.na(out$filepath))
  expect_true(is.na(out$dest_page))
  expect_gte(out$z_order, 0L)
  expect_equal(out$left,   50)
  expect_equal(out$bottom, 150)
  expect_equal(out$right,  200)
  expect_equal(out$top,    170)
})

test_that("pdf_link_at_point returns 0 rows when no link is under the point", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)
  out <- pdf_link_at_point(p, x = 10, y = 10)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("z_order", "left", "bottom", "right", "top",
                      "action_type", "uri", "filepath", "dest_page",
                      "dest_view", "dest_x", "dest_y", "dest_zoom"))
})

test_that("pdf_link_at_point validates x and y", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  p <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(p), add = TRUE, after = FALSE)

  expect_error(pdf_link_at_point(p, NA_real_, 10),     "finite numeric")
  expect_error(pdf_link_at_point(p, 10, c(1, 2)),       "finite numeric")
  expect_error(pdf_link_at_point(p, "100", 10),         "finite numeric")
  expect_error(pdf_link_at_point(p, 10, Inf),           "finite numeric")
})

test_that("pdf_link_at_point accepts a doc + page_num", {
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  out <- pdf_link_at_point(doc, x = 125, y = 160, page_num = 1L)
  expect_equal(nrow(out), 1L)
  expect_equal(out$action_type, "uri")
})

test_that("pdf_page_actions returns empty tibble for typical PDFs", {
  for (name in c("shapes", "outline", "annotated", "minimal")) {
    out <- pdf_page_actions(pdf_open(fixture_path(name)), 1L)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
    expect_named(out, c("trigger", "action_type", "uri", "filepath",
                        "dest_page", "dest_view", "dest_x", "dest_y",
                        "dest_zoom"))
  }
})

test_that("pdf_page_actions / pdf_link_at_point reject closed pages", {
  doc <- pdf_open(fixture_path("annotated"))
  p <- pdf_load_page(doc, 1L)
  pdf_close_page(p)
  expect_error(pdf_link_at_point(p, 1, 1), "closed")
  expect_error(pdf_page_actions(p),         "closed")
  pdf_close(doc)
})

test_that("page-nav functions reject bad page inputs", {
  expect_error(pdf_link_at_point("nope", 1, 1),
               "must be a `pdfium_page` or a `pdfium_doc`")
  expect_error(pdf_page_actions(42),
               "must be a `pdfium_page` or a `pdfium_doc`")
})
