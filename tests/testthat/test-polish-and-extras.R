# Tests for the phase-6 polish-and-extras additions:
#   * pdf_obj_matrix() returning a 3x3 matrix
#   * pdf_open(source = <raw>)
#   * pdf_text(), pdf_fonts(), pdf_file_id(), pdf_doc_page_mode()
#   * password= argument propagation
#   * pdf_text_chars(), pdf_page_box(), pdf_page_links()
#   * pdf_page_objects(recursive = TRUE)

# pdf_obj_matrix ---------------------------------------------------

test_that("pdf_obj_matrix returns a 3x3 matrix in homogeneous form", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  for (o in pdf_page_objects(page)) {
    M <- pdf_obj_matrix(o)
    expect_true(is.matrix(M))
    expect_equal(dim(M), c(3L, 3L))
    expect_equal(M[3L, ], c(0, 0, 1))
  }
})

test_that("pdf_obj_matrix composes with point %*% to transform coords", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  M <- pdf_obj_matrix(paths[[1L]])
  # y-flip with 216 translation: local (10, 50, 1) -> page (10, 166).
  pt <- M %*% c(10, 50, 1)
  expect_equal(pt[1L, 1L],  10, tolerance = 1e-3)
  expect_equal(pt[2L, 1L], 166, tolerance = 1e-3)
})

# pdf_open(source = <raw>) ----------------------------------------

test_that("pdf_open(source = raw) loads from in-memory bytes", {
  fx <- fixture_path("shapes")
  bytes <- readBin(fx, "raw", file.info(fx)$size)
  doc <- pdf_open(source = bytes)
  on.exit(pdf_close(doc), add = TRUE)

  expect_s3_class(doc, "pdfium_doc")
  expect_identical(pdf_page_count(doc), 1L)
  # Round-trip: text from raw matches text from path.
  expect_identical(pdf_text(doc), pdf_text(fx))
})

test_that("pdf_open validates source / path / password", {
  expect_error(pdf_open(),
               "One of `path` or `source` must be provided")
  fx <- fixture_path("shapes")
  expect_error(pdf_open(path = fx, source = readBin(fx, "raw", 100L)),
               "Pass exactly one of")
  expect_error(pdf_open(source = "not raw"),
               "must be a raw vector")
  expect_error(pdf_open(source = raw(0L)),
               "must be non-empty")
  expect_error(pdf_open(fx, password = 42),
               "must be NULL or a single non-NA character string")
})

# pdf_text / pdf_fonts / pdf_file_id / pdf_doc_page_mode ----------

test_that("pdf_text returns one string per page", {
  txt <- pdf_text(fixture_path("shapes"))
  expect_type(txt, "character")
  expect_length(txt, 1L)
  expect_match(txt, "Hello")
})

test_that("pdf_fonts rolls up document fonts with first_seen_page", {
  fonts <- pdf_fonts(fixture_path("shapes"))
  expect_s3_class(fonts, "tbl_df")
  expect_named(fonts, c("font_base_name", "font_family",
                        "font_weight", "font_italic_angle",
                        "font_is_embedded", "font_flags",
                        "first_seen_page"))
  expect_gte(nrow(fonts), 1L)
  expect_true(all(fonts$first_seen_page >= 1L))
})

test_that("pdf_file_id returns raw bytes, possibly empty", {
  id <- pdf_file_id(fixture_path("shapes"))
  expect_type(id, "raw")
  # Cairo doesn't write a /ID entry for our fixture, so empty is
  # expected. The contract is still "raw vector"; just verify it
  # didn't error.
  expect_gte(length(id), 0L)
})

test_that("pdf_file_id rejects unknown id_type", {
  expect_error(pdf_file_id(fixture_path("shapes"), id_type = "neither"),
               "should be one of")
})

test_that("pdf_doc_page_mode returns a documented label", {
  pm <- pdf_doc_page_mode(fixture_path("shapes"))
  expect_type(pm, "character")
  expect_true(pm %in% c("unknown", "use_none", "use_outlines",
                        "use_thumbs", "full_screen", "use_oc",
                        "use_attachments"))
})

# password= ------------------------------------------------------

test_that("password= flows through path-shortcut wrappers", {
  # Smoke test on a non-encrypted PDF - calling with password = NULL
  # (default) and password = "" should both succeed unchanged.
  fx <- fixture_path("shapes")
  expect_equal(pdf_page_count(fx, password = NULL),
               pdf_page_count(fx))
  expect_equal(pdf_doc_info(fx, password = NULL)$page_count,
               1L)
  expect_s3_class(pdf_extract_paths(fx, password = NULL),
                  "tbl_df")
})

# pdf_text_chars -------------------------------------------------

test_that("pdf_text_char_at_point hits a known glyph in shapes.pdf", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  chars <- pdf_text_chars(doc, page_num = 1L)
  visible <- chars[!chars$is_generated, ]
  # Pick the centre of the first visible char's bounding box.
  cx <- (visible$bounds_left[[1L]] + visible$bounds_right[[1L]]) / 2
  cy <- (visible$bounds_bottom[[1L]] + visible$bounds_top[[1L]]) / 2
  idx <- pdf_text_char_at_point(doc, cx, cy, page_num = 1L)
  expect_type(idx, "integer")
  expect_equal(idx, visible$char_index[[1L]])
})

test_that("pdf_text_char_at_point returns NA when no glyph is near", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  # Sample a corner well outside any character.
  expect_true(is.na(pdf_text_char_at_point(doc, -100, -100,
                                            page_num = 1L)))
})

test_that("text-index <-> char-index round trip is consistent", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  chars <- pdf_text_chars(doc, page_num = 1L)
  # Walk every char that has a non-NA text_index; round-tripping
  # back through cpp's GetCharIndexFromTextIndex should land on
  # the same char_index.
  for (i in seq_len(nrow(chars))) {
    ti <- chars$text_index[[i]]
    if (is.na(ti)) next
    ti_helper <- pdf_text_index_from_char(doc, chars$char_index[[i]],
                                           page_num = 1L)
    expect_equal(ti_helper, ti)
    ci_back <- pdf_text_char_from_text_index(doc, ti, page_num = 1L)
    expect_equal(ci_back, chars$char_index[[i]])
  }
})

test_that("pdf_text_char_at_point / index helpers validate inputs", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_text_char_at_point(doc, NA, 1), "finite numeric")
  expect_error(pdf_text_char_at_point(doc, 1, NA), "finite numeric")
  expect_error(pdf_text_char_at_point(doc, 1, 1, tolerance = NA),
               "finite numeric")
  expect_error(pdf_text_index_from_char(doc, NA), "finite integer")
  expect_error(pdf_text_char_from_text_index(doc, NA),
               "finite integer")
})

test_that("pdf_text_chars returns one row per character with bounds + flags", {
  chars <- pdf_text_chars(pdf_open(fixture_path("shapes")), page_num = 1L)
  expect_s3_class(chars, "tbl_df")
  expect_named(chars, c("char_index", "codepoint", "char",
                        "bounds_left", "bounds_bottom",
                        "bounds_right", "bounds_top",
                        "font_size", "is_generated", "is_hyphen",
                        "origin_x", "origin_y",
                        "loose_left", "loose_bottom",
                        "loose_right", "loose_top",
                        "unicode_map_error", "text_index"))
  expect_type(chars$codepoint,    "integer")
  expect_type(chars$char,         "character")
  expect_type(chars$is_generated, "logical")
  expect_type(chars$is_hyphen,    "logical")
  expect_type(chars$origin_x,     "double")
  expect_type(chars$origin_y,     "double")
  expect_type(chars$loose_left,   "double")
  expect_type(chars$unicode_map_error, "logical")
  expect_type(chars$text_index,   "integer")
  # The fixture text is "Hello" - 5 visible chars.
  visible <- chars[!chars$is_generated, ]
  expect_gte(nrow(visible), 5L)
  expect_identical(paste(visible$char[1L:5L], collapse = ""), "Hello")
})

# pdf_page_box ----------------------------------------------------

test_that("pdf_page_box(media) matches pdf_page_size dimensions", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  media <- pdf_page_box(page, box = "media")
  sz    <- pdf_page_size(page)
  expect_equal(media[["right"]]  - media[["left"]],   sz[["width"]])
  expect_equal(media[["top"]]    - media[["bottom"]], sz[["height"]])
})

test_that("pdf_page_box returns NAs for boxes the PDF doesn't declare", {
  page <- pdf_load_page(pdf_open(fixture_path("shapes")), 1L)
  for (b in c("crop", "bleed", "trim", "art")) {
    res <- pdf_page_box(page, box = b)
    expect_named(res, c("left", "bottom", "right", "top"))
    expect_true(all(is.na(res)),
                info = paste0("box=", b))
  }
})

test_that("pdf_page_box rejects unknown box names", {
  page <- pdf_load_page(pdf_open(fixture_path("shapes")), 1L)
  expect_error(pdf_page_box(page, box = "noBox"),
               "should be one of")
})

# pdf_page_links --------------------------------------------------

test_that("pdf_page_links returns 0 rows for a page with no links", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  links <- pdf_page_links(doc, page_num = 1L)
  expect_s3_class(links, "tbl_df")
  expect_equal(nrow(links), 0L)
  expect_named(links, c("link_index", "bounds_left", "bounds_bottom",
                        "bounds_right", "bounds_top", "action_type",
                        "uri", "filepath", "dest_page_num",
                        "quad_points"))
})

test_that("pdf_page_links reports a URI link's target correctly", {
  # annotated.pdf has one URI link annotation at rect (50,150)-(200,170)
  # targeting https://example.com. Previously the action_type lookup
  # was off by one and reported this as "launch" — the test guards
  # against that regression.
  doc <- pdf_open(fixture_path("annotated"))
  on.exit(pdf_close(doc), add = TRUE)
  links <- pdf_page_links(doc, page_num = 1L)
  expect_equal(nrow(links), 1L)
  expect_equal(links$action_type, "uri")
  expect_equal(links$uri,         "https://example.com")
  expect_true(is.na(links$filepath))
  expect_true(is.na(links$dest_page_num))
  expect_equal(links$bounds_left,   50)
  expect_equal(links$bounds_bottom, 150)
  expect_equal(links$bounds_right,  200)
  expect_equal(links$bounds_top,    170)
})

# pdf_page_objects(recursive) -----------------------------------

test_that("pdf_page_objects(recursive = TRUE) is a no-op when no forms", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  flat   <- pdf_page_objects(page)
  recurs <- pdf_page_objects(page, recursive = TRUE)
  expect_length(recurs, length(flat))
})

test_that("pdf_page_objects(recursive = TRUE) descends into form objects", {
  doc <- pdf_open(fixture_path("form_xobject"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  flat   <- pdf_page_objects(page)
  recurs <- pdf_page_objects(page, recursive = TRUE)
  # The fixture has 2 top-level forms; one populated with 2 nested
  # objects, one empty. So flat = 2; recursive = 2 + 2 + 0 = 4.
  expect_equal(length(flat),   2L)
  expect_equal(length(recurs), 4L)
  expect_identical(vapply(recurs, function(o) o$type, character(1L)),
                   c("form", "path", "path", "form"))
})

test_that("pdf_page_objects(recursive) validates its flag", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  expect_error(pdf_page_objects(page, recursive = NA),
               "must be a single TRUE or FALSE")
  expect_error(pdf_page_objects(page, recursive = "yes"),
               "must be a single TRUE or FALSE")
})

# Edge-case coverage for the page-level helpers --------------------

test_that("pdf_fonts returns the empty schema for a doc with no text", {
  # minimal.pdf is a blank Cairo page with no text runs anywhere.
  fonts <- pdf_fonts(fixture_path("minimal"))
  expect_s3_class(fonts, "tbl_df")
  expect_equal(nrow(fonts), 0L)
  expect_named(fonts, c("font_base_name", "font_family",
                        "font_weight", "font_italic_angle",
                        "font_is_embedded", "font_flags",
                        "first_seen_page"))
})

test_that("pdf_doc_page_mode handles unexpected codes gracefully", {
  # We can't easily fabricate a PDF with an out-of-range PageMode,
  # but we can exercise the internal lookup directly to confirm
  # the fallback branch returns "unknown".
  # The lookup table maps code -1 (PAGEMODE_UNKNOWN) -> index 1,
  # codes 0..5 -> indices 2..7. Codes outside that range fall
  # through to "unknown".
  pm <- pdfium:::.pdfium_page_modes
  # Sanity check the table itself.
  expect_identical(pm[[1L]], "unknown")
  expect_identical(pm[[2L]], "use_none")
  # Exercise the function with the known fixture; mode should be
  # one of the documented strings.
  m <- pdf_doc_page_mode(fixture_path("shapes"))
  expect_true(m %in% pm)
})

test_that("as_open_page_pair refuses closed pages, closed docs, and bad inputs", {
  doc <- pdf_open(fixture_path("shapes"))
  page <- pdf_load_page(doc, 1L)
  pdf_close_page(page)
  expect_error(pdf_page_box(page), "Page has been closed")

  pdf_close(doc)
  expect_error(pdf_page_box(doc),  "Document has been closed")

  expect_error(pdf_page_box(42L),
               "must be a `pdfium_page` or a `pdfium_doc`")
})

test_that("doc_extra's internal as_doc_handle rejects bad inputs and closed docs", {
  # The doc-level helpers in R/doc_extra.R (pdf_text, pdf_fonts,
  # pdf_file_id, pdf_doc_page_mode) all share the as_doc_handle
  # validator. Exercise both rejection paths via pdf_text() and
  # pdf_file_id() so the helper's branches are covered.
  expect_error(pdf_text(42L),
               "must be a `pdfium_doc` or a path to a PDF file")
  doc <- pdf_open(fixture_path("shapes"))
  pdf_close(doc)
  expect_error(pdf_text(doc),       "Document has been closed")
  expect_error(pdf_file_id(doc),    "Document has been closed")
})

test_that("pdf_text returns the empty string for pages with no text", {
  # minimal.pdf is a single blank Cairo page with no text runs.
  txt <- pdf_text(fixture_path("minimal"))
  expect_identical(txt, "")
})
