# Tests for pdf_page_thumbnail() and pdf_text_weblinks().

test_that("pdf_page_thumbnail returns raw(0) when page has no /Thumb", {
  for (name in c("shapes", "minimal", "annotated")) {
    out <- pdf_page_thumbnail(pdf_doc_open(fixture_path(name)), 1L)
    expect_type(out, "raw")
    expect_equal(length(out), 0L)
  }
})

test_that("pdf_page_thumbnail returns the embedded thumbnail bytes", {
  doc <- pdf_doc_open(fixture_path("with_thumbnail"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  # The fixture's /Thumb is an uncompressed 4x4 8-bit gray image
  # with payload bytes 0x00, 0x10, ..., 0xF0.
  expected <- as.raw(seq(0L, 240L, by = 16L))

  raw_bytes <- pdf_page_thumbnail(p, decoded = FALSE)
  decoded_bytes <- pdf_page_thumbnail(p, decoded = TRUE)
  expect_type(raw_bytes, "raw")
  expect_type(decoded_bytes, "raw")
  expect_equal(raw_bytes, expected)
  expect_equal(decoded_bytes, expected)
})

test_that("pdf_page_thumbnail accepts a doc + page_num", {
  doc <- pdf_doc_open(fixture_path("with_thumbnail"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_page_thumbnail(doc, page_num = 1L)
  expect_equal(length(out), 16L)
})

test_that("pdf_page_thumbnail validates `decoded`", {
  doc <- pdf_doc_open(fixture_path("with_thumbnail"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_page_thumbnail(doc, decoded = NA), "Assertion on")
  expect_error(
    pdf_page_thumbnail(doc, decoded = c(TRUE, FALSE)),
    "Assertion on"
  )
  expect_error(pdf_page_thumbnail(doc, decoded = "yes"), "Assertion on")
})

test_that("pdf_text_weblinks returns 0-row tibble when page has no URLs", {
  for (name in c("shapes", "minimal", "unicode")) {
    out <- pdf_text_weblinks(pdf_doc_open(fixture_path(name)), 1L)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
    expect_named(out, c(
      "url", "start_char", "char_count",
      "left", "bottom", "right", "top"
    ))
  }
})

test_that("pdf_text_weblinks detects URLs in extracted text", {
  doc <- pdf_doc_open(fixture_path("weblinks"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  out <- pdf_text_weblinks(p)
  expect_s3_class(out, "tbl_df")
  expect_gte(nrow(out), 2L)
  # The two URLs we drew are present (order may vary by line order).
  expect_true(any(grepl("example.com", out$url)))
  expect_true(any(grepl("example.org", out$url)))
  # Each URL has a valid text-range and a finite bounding box.
  expect_true(all(out$char_count > 0L))
  expect_true(all(is.finite(out$left)))
  expect_true(all(is.finite(out$bottom)))
  expect_true(all(is.finite(out$right)))
  expect_true(all(is.finite(out$top)))
  expect_true(all(out$right >= out$left))
  expect_true(all(out$top >= out$bottom))
})

test_that("pdf_text_weblinks accepts a doc + page_num", {
  doc <- pdf_doc_open(fixture_path("weblinks"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_text_weblinks(doc, page_num = 1L)
  expect_s3_class(out, "tbl_df")
  expect_gte(nrow(out), 2L)
})

test_that("pdf_page_thumbnail / pdf_text_weblinks reject closed pages", {
  doc <- pdf_doc_open(fixture_path("with_thumbnail"))
  p <- pdf_page_load(doc, 1L)
  pdf_page_close(p)
  expect_error(pdf_page_thumbnail(p), "closed")
  expect_error(pdf_text_weblinks(p), "closed")
  pdf_doc_close(doc)
})

test_that("page-thumbnail / weblinks reject bad page inputs", {
  expect_error(
    pdf_page_thumbnail("nope"),
    "class .pdfium_page./.pdfium_doc."
  )
  expect_error(
    pdf_text_weblinks(42),
    "class .pdfium_page./.pdfium_doc."
  )
})
