# Tests for the glyph-path / font-metrics / per-char-font extras
# added when the v0.1.0 Tier 3 deferrals were un-deferred for the
# "challenging character mapping" use case.

helper_text_obj <- function() {
  doc <- pdf_open(fixture_path("shapes"))
  page <- pdf_load_page(doc, 1L)
  text <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  list(doc = doc, page = page, obj = text[[1L]])
}

test_that("pdf_glyph_path returns a non-empty segment tibble for 'H'", {
  bundle <- helper_text_obj()
  on.exit(pdf_close(bundle$doc), add = TRUE)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)
  # shapes.pdf draws "Hello"; first visible codepoint is 0x48 = 'H'.
  gp <- pdf_glyph_path(bundle$obj, 0x48L)
  expect_s3_class(gp, "tbl_df")
  expect_named(gp, c(
    "segment_index", "segment_type", "x", "y",
    "close_figure"
  ))
  expect_gt(nrow(gp), 0L)
  expect_true(all(gp$segment_type %in% c(
    "moveto", "lineto",
    "bezierto", "unknown"
  )))
  expect_true(all(is.finite(gp$x)))
  expect_true(all(is.finite(gp$y)))
})

test_that("pdf_glyph_path validates obj type, glyph_code, font_size", {
  bundle <- helper_text_obj()
  on.exit(pdf_close(bundle$doc), add = TRUE)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)
  expect_error(
    pdf_glyph_path("nope", 0x48L),
    "must be a `pdfium_obj`"
  )
  expect_error(
    pdf_glyph_path(bundle$obj, -1L),
    "non-negative integer"
  )
  expect_error(
    pdf_glyph_path(bundle$obj, NA),
    "non-negative integer"
  )
  expect_error(
    pdf_glyph_path(bundle$obj, 0x48L, font_size = "12"),
    "single numeric"
  )
  expect_error(
    pdf_glyph_path(bundle$obj, 0x48L, font_size = c(1, 2)),
    "single numeric"
  )
})

test_that("pdf_glyph_width returns a sensible width for 'H'", {
  bundle <- helper_text_obj()
  on.exit(pdf_close(bundle$doc), add = TRUE)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)
  # At unit font size, glyph widths are advance-width units typically
  # in the 0.4 - 1.0 range for Latin letters.
  w <- pdf_glyph_width(bundle$obj, 0x48L, font_size = 1)
  expect_type(w, "double")
  expect_true(is.finite(w))
  expect_gt(w, 0.1)
  expect_lt(w, 2.0)
})

test_that("pdf_text_font_metrics returns ascent + descent", {
  bundle <- helper_text_obj()
  on.exit(pdf_close(bundle$doc), add = TRUE)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)
  m <- pdf_text_font_metrics(bundle$obj, font_size = 12)
  expect_named(m, c("ascent", "descent"))
  expect_gt(m$ascent, 0)
  expect_lt(m$descent, 0)
  # Ascent + |descent| together must be larger than the font size
  # (em-height in PDF is the font-size; ascent + descent typically
  # exceeds it slightly).
  expect_gt(m$ascent - m$descent, 12)
})

test_that("pdf_glyph_width validates obj type, glyph_code, font_size", {
  bundle <- helper_text_obj()
  on.exit(pdf_close(bundle$doc), add = TRUE)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)
  expect_error(pdf_glyph_width("nope", 0x48L),
               "must be a `pdfium_obj`")
  expect_error(pdf_glyph_width(bundle$obj, -1L),
               "non-negative integer")
  expect_error(pdf_glyph_width(bundle$obj, NA),
               "non-negative integer")
  expect_error(pdf_glyph_width(bundle$obj, c(1L, 2L)),
               "non-negative integer")
  expect_error(pdf_glyph_width(bundle$obj, 0x48L, font_size = "12"),
               "single numeric")
  expect_error(pdf_glyph_width(bundle$obj, 0x48L, font_size = c(1, 2)),
               "single numeric")
})

test_that("pdf_text_font_metrics validates font_size", {
  bundle <- helper_text_obj()
  on.exit(pdf_close(bundle$doc), add = TRUE)
  on.exit(pdf_close_page(bundle$page), add = TRUE, after = FALSE)
  expect_error(
    pdf_text_font_metrics(bundle$obj, font_size = 0),
    "positive finite numeric"
  )
  expect_error(
    pdf_text_font_metrics(bundle$obj, font_size = NA),
    "positive finite numeric"
  )
})

test_that("pdf_text_chars exposes per-char font_name + flags", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  chars <- pdf_text_chars(doc, page_num = 1L)
  expect_true("char_font_name" %in% names(chars))
  expect_true("char_font_flags" %in% names(chars))
  visible <- chars[!chars$is_generated, ]
  expect_true(all(nzchar(visible$char_font_name)))
  expect_true(all(is.finite(visible$char_font_flags)))
})
