# Tests for the glyph-path / font-metrics / per-char-font extras
# added when the v0.1.0 Tier 3 deferrals were un-deferred for the
# "challenging character mapping" use case.

helper_text_obj <- function() {
  doc <- pdf_doc_open(fixture_path("shapes")) # nolint: object_usage_linter
  page <- pdf_page_load(doc, 1L)
  text <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  list(doc = doc, page = page, obj = text[[1L]])
}

test_that("pdf_glyph_path returns a non-empty segment tibble for 'H'", {
  bundle <- helper_text_obj()
  on.exit(pdf_doc_close(bundle$doc), add = TRUE)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)
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
  on.exit(pdf_doc_close(bundle$doc), add = TRUE)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)
  expect_error(
    pdf_glyph_path("nope", 0x48L),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_glyph_path(bundle$obj, -1L),
    "Assertion on"
  )
  expect_error(
    pdf_glyph_path(bundle$obj, NA),
    "Assertion on"
  )
  expect_error(
    pdf_glyph_path(bundle$obj, 0x48L, font_size = "12"),
    "Assertion on"
  )
  expect_error(
    pdf_glyph_path(bundle$obj, 0x48L, font_size = c(1, 2)),
    "Assertion on"
  )
})

test_that("pdf_glyph_width returns a sensible width for 'H'", {
  bundle <- helper_text_obj()
  on.exit(pdf_doc_close(bundle$doc), add = TRUE)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)
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
  on.exit(pdf_doc_close(bundle$doc), add = TRUE)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)
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
  on.exit(pdf_doc_close(bundle$doc), add = TRUE)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)
  expect_error(
    pdf_glyph_width("nope", 0x48L),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_glyph_width(bundle$obj, -1L),
    "Assertion on"
  )
  expect_error(
    pdf_glyph_width(bundle$obj, NA),
    "Assertion on"
  )
  expect_error(
    pdf_glyph_width(bundle$obj, c(1L, 2L)),
    "Assertion on"
  )
  expect_error(
    pdf_glyph_width(bundle$obj, 0x48L, font_size = "12"),
    "Assertion on"
  )
  expect_error(
    pdf_glyph_width(bundle$obj, 0x48L, font_size = c(1, 2)),
    "Assertion on"
  )
})

test_that("pdf_text_font_metrics validates font_size", {
  bundle <- helper_text_obj()
  on.exit(pdf_doc_close(bundle$doc), add = TRUE)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)
  expect_error(
    pdf_text_font_metrics(bundle$obj, font_size = 0),
    "Assertion on"
  )
  expect_error(
    pdf_text_font_metrics(bundle$obj, font_size = NA),
    "Assertion on"
  )
})

test_that("pdf_text_chars exposes per-char font_name + flags", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  chars <- pdf_text_chars(doc, page_num = 1L)
  expect_true("char_font_name" %in% names(chars))
  expect_true("char_font_flags" %in% names(chars))
  visible <- chars[!chars$is_generated, ]
  expect_true(all(nzchar(visible$char_font_name)))
  expect_true(all(is.finite(visible$char_font_flags)))
})

# The R wrappers refuse non-text page-objects via check_pdfium_obj(),
# so the FPDFTextObj_GetFont == NULL branches in the C++ shims are
# only reachable through direct cpp_* calls with a non-text obj.
# Pass a `path` page-object handle through and confirm each shim
# returns the empty / NA shape rather than crashing.
test_that("glyph cpp shims handle non-text page-objects gracefully", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  non_text <- Filter(
    function(o) o$type != "text", pdf_page_objects(page)
  )
  expect_gt(length(non_text), 0L)
  obj <- non_text[[1L]]

  # cpp_text_obj_glyph_path: FPDFTextObj_GetFont(path) returns NULL
  # so the function returns four empty columns of the right types.
  gp <- pdfium:::cpp_text_obj_glyph_path(obj$ptr, 0x48L, 12.0)
  expect_named(gp, c("segment_type", "x", "y", "close"))
  expect_length(gp$segment_type, 0L)
  expect_length(gp$x, 0L)
  expect_length(gp$y, 0L)
  expect_length(gp$close, 0L)

  # cpp_text_obj_glyph_width: same null-font early return -> NA.
  w <- pdfium:::cpp_text_obj_glyph_width(obj$ptr, 0x48L, 12.0)
  expect_true(is.na(w))

  # cpp_text_obj_font_metrics: same null-font early return -> NA, NA.
  m <- pdfium:::cpp_text_obj_font_metrics(obj$ptr, 12.0)
  expect_named(m, c("ascent", "descent"))
  expect_true(is.na(m$ascent))
  expect_true(is.na(m$descent))
})

# Reaching FPDFFont_GetGlyphPath == NULL requires a font that
# rejects the requested glyph code at the GetGlyphPath call. The
# Cairo-emitted CID-keyed fonts in shapes.pdf return a non-NULL
# glyphpath with zero segments for unknown codes; provoke the
# nullptr branch via a glyph code that's almost certainly past the
# embedded subset (most subsets stop well before 0x10FFFE).
test_that("cpp_text_obj_glyph_path tolerates unknown glyph codes", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  text_objs <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  obj <- text_objs[[1L]]
  for (code in c(0L, 0xFFFFL, 0xFFFFFL, 0x10FFFEL)) {
    gp <- pdfium:::cpp_text_obj_glyph_path(
      obj$ptr, as.integer(code), 1.0
    )
    expect_named(gp, c("segment_type", "x", "y", "close"))
    # Each unknown code returns the right shape (possibly empty,
    # possibly the .notdef glyph). What matters is "no crash, no
    # NA in the type column when segments do come back".
    if (length(gp$segment_type) > 0L) {
      expect_true(all(!is.na(gp$segment_type)))
    }
  }

  # Same for glyph width: PDFium's behavior for unknown codes is to
  # report success with width 0 rather than failure, so the function
  # returns 0 (not NA) for these.
  w0 <- pdfium:::cpp_text_obj_glyph_width(obj$ptr, 0xFFFFFFL, 1.0)
  expect_true(is.finite(w0))
  expect_equal(w0, 0)
})

# The R wrapper for pdf_text_font_metrics() enforces font_size > 0
# but the C++ shim accepts any double. Exercise the non-finite /
# non-positive branch directly so the `fs = 1.f` fallback is
# instrumented.
test_that("cpp_text_obj_font_metrics defaults to fs=1 for bad font_size", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  text_objs <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  obj <- text_objs[[1L]]
  # Non-finite + non-positive both trigger fs=1.f at line 151.
  for (fs in c(NA_real_, NaN, -1.0, 0.0)) {
    m <- pdfium:::cpp_text_obj_font_metrics(obj$ptr, fs)
    expect_named(m, c("ascent", "descent"))
    expect_true(is.finite(m$ascent))
    expect_lt(m$descent, 0)
  }
})

# Likewise cpp_text_obj_glyph_path / cpp_text_obj_glyph_width accept
# any double and fall back to the page-object's own font size when
# the caller asks for it (NA / non-positive). Confirm the two
# fallbacks reach the FPDFTextObj_GetFontSize success branch.
test_that("cpp_text_obj_glyph_* fall back to the obj's font size", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  text_objs <- Filter(function(o) o$type == "text", pdf_page_objects(page))
  obj <- text_objs[[1L]]
  for (fs in c(NA_real_, NaN, -2.0, 0.0)) {
    gp <- pdfium:::cpp_text_obj_glyph_path(obj$ptr, 0x48L, fs)
    expect_named(gp, c("segment_type", "x", "y", "close"))
    expect_gt(length(gp$segment_type), 0L)
    w <- pdfium:::cpp_text_obj_glyph_width(obj$ptr, 0x48L, fs)
    expect_true(is.finite(w))
    expect_gt(w, 0)
  }
})
