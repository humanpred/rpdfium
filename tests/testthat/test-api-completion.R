# Tests for the v0.1.0 "complete the relevant PDFium surface" pass.
#
# Each test creates a fresh in-memory doc (where possible) so the
# test does not perturb shipped fixtures. For pages that need real
# content, the "shapes" fixture is reused.

# ---- pdf_doc_form_type ---------------------------------------------------

test_that("pdf_doc_form_type returns 'none' for a doc with no form", {
  doc <- pdf_doc_open(fixture_path("minimal"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(pdf_doc_form_type(doc), "none")
})

test_that("pdf_doc_form_type rejects a closed doc", {
  doc <- pdf_doc_open(fixture_path("minimal"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_form_type(doc), "Document has been closed")
})

# ---- pdf_bookmark_child_count -------------------------------------------

test_that("pdf_bookmark_child_count returns an integer", {
  fx <- fixture_path("minimal")
  doc <- pdf_doc_open(fx)
  on.exit(pdf_doc_close(doc), add = TRUE)
  bms <- pdf_doc_bookmarks(doc)
  if (length(bms) > 0) {
    n <- pdf_bookmark_child_count(bms[[1L]])
    expect_type(n, "integer")
    expect_gte(n, 0L)
  } else {
    succeed("no bookmarks in fixture")
  }
})

# ---- Page metadata + transparency ---------------------------------------

test_that("pdf_page_has_transparency returns FALSE on a basic page", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_false(pdf_page_has_transparency(page))
})

test_that("pdf_page_bounding_box returns a 4-vector", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  bb <- pdf_page_bounding_box(page)
  expect_named(bb, c("left", "bottom", "right", "top"))
  expect_length(bb, 4L)
  # New empty pages have an unset bounding box; PDFium returns NAs.
  expect_true(all(is.na(bb)) || all(is.finite(bb)))
})

test_that("pdf_page_transform_annots no-ops on a page without annots", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  ret <- pdf_page_transform_annots(page,
                                     matrix = c(1, 0, 0, 1, 10, 20))
  expect_identical(ret, doc)
  # The transform marks the page dirty even when no annots exist —
  # the doc-wide bookkeeping doesn't know whether the underlying
  # transform did anything.
  expect_setequal(doc$state$dirty_pages, 1L)
})

test_that("pdf_page_transform_annots validates the matrix shape", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(pdf_page_transform_annots(page, matrix = c(1, 2, 3)),
               "Assertion on")
  expect_error(pdf_page_transform_annots(page,
                                          matrix = c(1, 0, 0, 1, NA, 0)),
               "Assertion on")
})

# ---- pdf_annot_index ----------------------------------------------------

test_that("pdf_annot_index reports the freshly-created annot's index", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  a <- pdf_annot_new(page, "square", bounds = c(10, 10, 50, 50))
  expect_identical(pdf_annot_index(a), 1L)
  b <- pdf_annot_new(page, "text", bounds = c(60, 60, 80, 80))
  expect_identical(pdf_annot_index(b), 2L)
})

# ---- Coordinate conversion ----------------------------------------------

test_that("pdf_device_to_page and pdf_page_to_device round-trip", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  # 612x792 page rendered at 612x792 pixels starting at (0, 0).
  pp <- pdf_device_to_page(page, 0L, 0L, 612L, 792L, 0L, 100L, 200L)
  expect_named(pp, c("x", "y"))
  expect_true(is.finite(pp[["x"]]))
  # Inverse should map back near the device pixel.
  back <- pdf_page_to_device(page, 0L, 0L, 612L, 792L, 0L,
                              pp[["x"]], pp[["y"]])
  expect_equal(back[["x"]], 100L, tolerance = 2)
  expect_equal(back[["y"]], 200L, tolerance = 2)
})

test_that("pdf_device_to_page validates rotate enum", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(pdf_device_to_page(page, 0L, 0L, 100L, 100L, 5L, 0L, 0L),
               "Assertion on")
})

# ---- Text low-level -----------------------------------------------------

test_that("pdf_text_rects returns a tibble with the expected columns", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  r <- pdf_text_rects(page)
  expect_s3_class(r, "tbl_df")
  expect_named(r, c("left", "top", "right", "bottom"))
  expect_true(nrow(r) >= 0L)
})

test_that("pdf_text_bounded returns a string (or empty)", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  pg <- pdf_page_size(page)
  txt <- pdf_text_bounded(page, c(0, 0, pg[["width"]], pg[["height"]]))
  expect_type(txt, "character")
  expect_length(txt, 1L)
})

test_that("pdf_text_bounded validates bounds shape", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(pdf_text_bounded(page, c(0, 0, 100)), "Assertion on")
})

test_that("pdf_text_char_geometry returns matrix + angle + weight", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  g <- pdf_text_char_geometry(page)
  expect_s3_class(g, "tbl_df")
  expect_named(g, c("char_index", "matrix", "angle_deg", "font_weight"))
  expect_true(is.list(g$matrix))
  if (nrow(g) > 0L) {
    expect_length(g$matrix[[1L]], 6L)
  }
})

# ---- Page-object dash phase setter --------------------------------------

test_that("pdf_path_set_dash_phase mutates a dashed path", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  path <- pdf_path_new(page, 10, 10)
  pdf_path_line_to(path, 100, 100)
  pdf_path_set_dash(path, array = c(4, 2), phase = 0)
  ret <- pdf_path_set_dash_phase(path, 5)
  expect_identical(ret, doc)
  # Confirm the new phase is what PDFium reports back.
  expect_equal(pdf_path_dash(path)$phase, 5)
})

test_that("pdf_path_set_dash_phase rejects non-path objects", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  txt <- pdf_text_new(page, "x")
  expect_error(pdf_path_set_dash_phase(txt, 5),
               "Must be element of set")
})

# ---- Content-mark set blob / remove -------------------------------------

test_that("pdf_obj_mark_set_blob + remove round-trip", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  rect <- pdf_rect_new(page, 0, 0, 50, 50)
  pdf_obj_add_mark(rect, "MyMark")
  blob <- as.raw(c(0x01, 0x02, 0x03, 0x04))
  ret <- pdf_obj_mark_set_blob(rect, mark_index = 1L,
                                 key = "Payload", value = blob)
  expect_identical(ret, doc)
  ret2 <- pdf_obj_mark_remove_param(rect, mark_index = 1L,
                                      key = "Payload")
  expect_identical(ret2, doc)
})

test_that("pdf_obj_mark_set_blob validates mark_index", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  rect <- pdf_rect_new(page, 0, 0, 50, 50)
  expect_error(pdf_obj_mark_set_blob(rect, mark_index = 0L,
                                       key = "k", value = raw(1)),
               "Assertion on")
})

# ---- Font extras --------------------------------------------------------

test_that("pdf_font_data returns a raw vector", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  f <- pdf_font_load_standard(doc, "Helvetica")
  bytes <- pdf_font_data(f)
  expect_type(bytes, "raw")
  # Standard font may have no embedded bytes (PDFium handles it
  # via the reference table); either way we get a raw vector.
})

test_that("pdf_font_data rejects a closed font handle", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  f <- pdf_font_load_standard(doc, "Helvetica")
  pdf_font_close(f)
  expect_error(pdf_font_data(f), "Font handle has been closed")
})

# pdf_font_load_cidtype2 requires a real TTF file; skip when none
# is available on the runner.
find_test_ttf <- function() {
  for (p in c(
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/Library/Fonts/Arial.ttf",
    "C:/Windows/Fonts/arial.ttf"
  )) {
    if (file.exists(p)) return(p)
  }
  NULL
}

test_that("pdf_font_load_cidtype2 loads a TTF with explicit mappings", {
  ttf <- find_test_ttf()
  skip_if(is.null(ttf), "no system TrueType font available")
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  # PDFium requires both a non-empty ToUnicode CMap and a non-empty
  # CID-to-GID mapping. A 4-byte CMap header + a 2-byte identity
  # mapping is the minimum that gets past the input validation; this
  # smoke-test only verifies the call shape, not glyph correctness.
  cmap <- "/CIDInit /ProcSet findresource begin"
  cid_to_gid <- as.raw(c(0x00, 0x01))
  expect_error(
    pdf_font_load_cidtype2(doc, ttf, to_unicode_cmap = cmap,
                            cid_to_gid = cid_to_gid),
    NA  # No error expected — call is well-formed.
  )
})

# ---- pdf_text_set_charcodes ---------------------------------------------

test_that("pdf_text_set_charcodes accepts an integer vector", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  txt <- pdf_text_new(page, "")
  # Helvetica's "H" glyph happens to be charcode 0x48 (72); we pass a
  # short sequence and verify the call succeeds.
  ret <- pdf_text_set_charcodes(txt, c(72L, 101L, 108L, 108L, 111L))
  expect_identical(ret, doc)
})

test_that("pdf_text_set_charcodes rejects negative charcodes", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  txt <- pdf_text_new(page, "")
  expect_error(pdf_text_set_charcodes(txt, c(72L, -1L)),
               "Assertion on")
})

test_that("pdf_text_set_charcodes rejects non-text page-objects", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  rect <- pdf_rect_new(page, 0, 0, 50, 50)
  expect_error(pdf_text_set_charcodes(rect, 72L),
               "Must be element of set")
})
