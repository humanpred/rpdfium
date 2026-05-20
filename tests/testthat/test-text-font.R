# Tests for pdf_text_font() and the font columns of pdf_text_runs().

test_that("pdf_text_font returns the documented six-element list", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  fn <- pdf_text_font(text_obj)
  expect_named(fn, c(
    "font_base_name", "font_family", "font_weight",
    "font_italic_angle", "font_is_embedded",
    "font_flags"
  ))
  expect_type(fn$font_base_name, "character")
  expect_type(fn$font_family, "character")
  expect_type(fn$font_weight, "integer")
  expect_type(fn$font_italic_angle, "integer")
  expect_type(fn$font_is_embedded, "logical")
  expect_type(fn$font_flags, "integer")
})

test_that("pdf_text_font reports sensible values for Cairo-embedded text", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  fn <- pdf_text_font(text_obj)

  # Cairo always embeds the font subset, regardless of which font
  # the build machine has installed - so this assertion is portable.
  expect_true(fn$font_is_embedded)

  # Font names are system-dependent (Cairo uses whatever sans serif
  # the machine ships - NimbusSans on Debian, Helvetica on macOS,
  # ArialMT on Windows). We only assert they are non-empty strings.
  expect_true(nzchar(fn$font_base_name))
  expect_true(nzchar(fn$font_family))

  # Weight is in the standard typographic 100-900 range, with 400
  # being "regular" - graphics::text() with no explicit face uses
  # regular weight.
  expect_gte(fn$font_weight, 100L)
  expect_lte(fn$font_weight, 900L)

  # Italic angle is between -90 and 90 degrees; 0 for upright.
  expect_gte(fn$font_italic_angle, -90L)
  expect_lte(fn$font_italic_angle, 90L)

  # Flags is the PDF font-descriptor bitmask, a non-negative
  # integer. Cairo-emitted subsets typically set the Symbolic bit.
  expect_gte(fn$font_flags, 0L)
})

test_that("pdf_text_font validates input and refuses non-text objects", {
  expect_error(pdf_text_font("nope"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  path_obj <- Filter(
    function(o) o$type == "path",
    pdf_page_objects(page)
  )[[1]]
  expect_error(
    pdf_text_font(path_obj),
    "Must be element of set"
  )
})

test_that("pdf_text_font refuses objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  pdf_page_close(page)
  expect_error(
    pdf_text_font(text_obj),
    "Parent page has been closed"
  )
})

test_that("pdf_text_runs now includes font_* columns", {
  res <- pdf_text_runs(pdf_doc_open(fixture_path("unicode")))
  expect_named(res, c(
    "obj_index", "bounds_left", "bounds_bottom",
    "bounds_right", "bounds_top", "font_size", "text",
    "font_base_name", "font_family", "font_weight",
    "font_italic_angle", "font_is_embedded",
    "font_flags"
  ))
  expect_type(res$font_base_name, "character")
  expect_type(res$font_family, "character")
  expect_type(res$font_weight, "integer")
  expect_type(res$font_italic_angle, "integer")
  expect_type(res$font_is_embedded, "logical")
  expect_type(res$font_flags, "integer")
  expect_true(all(nzchar(res$font_base_name)))
  expect_true(all(nzchar(res$font_family)))
  expect_true(all(res$font_is_embedded)) # Cairo embeds all fonts
})

test_that("pdf_text_font scalars match pdf_text_runs row for the same obj", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  text_obj <- Filter(
    function(o) o$type == "text",
    pdf_page_objects(page)
  )[[1]]
  fn <- pdf_text_font(text_obj)
  rs <- pdf_text_runs(page)
  expect_equal(nrow(rs), 1L)
  expect_identical(fn$font_base_name, rs$font_base_name[[1]])
  expect_identical(fn$font_family, rs$font_family[[1]])
  expect_identical(fn$font_weight, rs$font_weight[[1]])
  expect_identical(fn$font_italic_angle, rs$font_italic_angle[[1]])
  expect_identical(fn$font_is_embedded, rs$font_is_embedded[[1]])
  expect_identical(fn$font_flags, rs$font_flags[[1]])
})
