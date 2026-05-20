# Tests for the text-appearance readouts added in the 0.1.0
# read-completion pass: pdf_text_render_mode (per-text-object) and
# pdf_text_colors (per-character fill/stroke + text-index).

test_that("pdf_text_render_mode returns a documented mode string", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  texts <- Filter(function(o) o$type == "text", pdf_page_objects(p))
  skip_if(length(texts) == 0L, "no text objects on shapes.pdf")

  modes <- vapply(texts, pdf_text_render_mode, character(1L))
  expect_true(all(modes %in% c(
    "fill", "stroke", "fill_stroke",
    "invisible", "fill_clip", "stroke_clip",
    "fill_stroke_clip", "clip", "unknown"
  )))
})

test_that("pdf_text_render_mode rejects non-text objects", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  paths <- Filter(function(o) o$type == "path", pdf_page_objects(p))
  skip_if(length(paths) == 0L, "no path objects on shapes.pdf")
  expect_error(pdf_text_render_mode(paths[[1L]]), "Must be element of set")
})

test_that("pdf_text_render_mode rejects bad inputs", {
  expect_error(pdf_text_render_mode(42), "class .pdfium_obj.")
  expect_error(pdf_text_render_mode(NULL), "class .pdfium_obj.")
})

test_that("pdf_text_colors returns one row per character with stable columns", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  out <- pdf_text_colors(p)
  expect_s3_class(out, "tbl_df")
  expect_named(out, c(
    "char_index", "text_index",
    "fill_red", "fill_green", "fill_blue", "fill_alpha",
    "stroke_red", "stroke_green", "stroke_blue", "stroke_alpha"
  ))
  expect_type(out$char_index, "integer")
  expect_type(out$text_index, "integer")
  for (cn in c(
    "fill_red", "fill_green", "fill_blue", "fill_alpha",
    "stroke_red", "stroke_green", "stroke_blue", "stroke_alpha"
  )) {
    expect_type(out[[cn]], "integer")
  }
  # shapes.pdf has "Hello" (5 chars).
  expect_gte(nrow(out), 5L)
})

test_that("pdf_text_colors fill colors are in 0..255 when set", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  out <- pdf_text_colors(p)
  fills <- out[!is.na(out$fill_red), ]
  for (cn in c("fill_red", "fill_green", "fill_blue", "fill_alpha")) {
    expect_true(all(fills[[cn]] >= 0L & fills[[cn]] <= 255L))
  }
})

test_that("pdf_text_colors accepts a doc + page_num", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  from_doc <- pdf_text_colors(doc, page_num = 1L)
  expect_s3_class(from_doc, "tbl_df")
  expect_gte(nrow(from_doc), 5L)
})

test_that("pdf_text_colors rejects bad inputs", {
  expect_error(
    pdf_text_colors("not a page"),
    "class .pdfium_page./.pdfium_doc."
  )
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(pdf_text_colors(doc), "closed")
})

test_that("pdf_text_colors text_index aligns with pdf_text_chars", {
  doc <- pdf_doc_open(fixture_path("unicode"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  chars <- pdf_text_chars(p)
  colors <- pdf_text_colors(p)
  expect_equal(nrow(chars), nrow(colors))
  expect_equal(chars$char_index, colors$char_index)
})
