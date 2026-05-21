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

# =========================================================================
# Phase B — annotation authoring completers
# =========================================================================

annot_blank_page <- function(envir = parent.frame()) {
  doc <- pdf_doc_new()
  withr::defer(pdf_doc_close(doc), envir = envir)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  withr::defer(pdf_page_close(page), envir = envir,
                priority = "first")
  list(doc = doc, page = page)
}

test_that("pdf_annot_add_ink_stroke appends a stroke", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "ink", bounds = c(0, 0, 100, 100))
  pts <- matrix(c(10, 10, 50, 50, 90, 10), ncol = 2, byrow = TRUE)
  idx <- pdf_annot_add_ink_stroke(a, pts)
  expect_identical(idx, 1L)
})

test_that("pdf_annot_remove_ink_list clears strokes", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "ink", bounds = c(0, 0, 100, 100))
  pts <- matrix(c(10, 10, 50, 50), ncol = 2, byrow = TRUE)
  pdf_annot_add_ink_stroke(a, pts)
  ret <- pdf_annot_remove_ink_list(a)
  expect_identical(ret, s$doc)
})

test_that("pdf_annot_object_count is 0 for a fresh annotation", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "stamp", bounds = c(0, 0, 100, 100))
  expect_identical(pdf_annot_object_count(a), 0L)
  expect_length(pdf_annot_objects(a), 0L)
})

test_that("pdf_annot_set_uri sets the URI on a link annotation", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "link", bounds = c(0, 0, 100, 100))
  ret <- pdf_annot_set_uri(a, "https://example.com/")
  expect_identical(ret, s$doc)
})

test_that("pdf_annot_set_appearance accepts each mode", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "stamp", bounds = c(0, 0, 100, 100))
  for (m in c("normal", "rollover", "down")) {
    expect_identical(
      pdf_annot_set_appearance(a, mode = m, value = ""),
      s$doc
    )
  }
})

test_that("pdf_annot_set_appearance rejects unknown modes", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "stamp", bounds = c(0, 0, 100, 100))
  expect_error(pdf_annot_set_appearance(a, mode = "highlight"),
               "Must be element of set")
})

test_that("pdf_annot_line returns NA-filled vector for non-line annots", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "square", bounds = c(0, 0, 100, 100))
  v <- pdf_annot_line(a)
  expect_named(v, c("start_x", "start_y", "end_x", "end_y"))
  expect_true(all(is.na(v)))
})

test_that("pdf_annot_link returns NULL for non-link annots", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "square", bounds = c(0, 0, 100, 100))
  expect_null(pdf_annot_link(a))
})

test_that("pdf_annot_link reports the URI of a link annotation", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "link", bounds = c(0, 0, 100, 100))
  pdf_annot_set_uri(a, "https://example.com/")
  info <- pdf_annot_link(a)
  expect_s3_class(info, "tbl_df")
  expect_identical(info$action_type, "uri")
  expect_identical(info$uri, "https://example.com/")
})

test_that("pdf_annot_set_border accepts radii + width", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "square", bounds = c(0, 0, 100, 100))
  ret <- pdf_annot_set_border(a, horizontal_radius = 3,
                                 vertical_radius = 3, border_width = 2)
  expect_identical(ret, s$doc)
})

# =========================================================================
# Phase C — clip-path authoring
# =========================================================================

test_that("pdf_clip_path_new builds a pdfium_clip_box", {
  cp <- pdf_clip_path_new(c(72, 72, 540, 720))
  expect_s3_class(cp, "pdfium_clip_box")
  expect_match(format(cp), "left=72")
})

test_that("pdf_clip_path_new validates the bounds vector", {
  expect_error(pdf_clip_path_new(c(72, 72, 540)), "Assertion on")
  expect_error(pdf_clip_path_new(c(NA, 72, 540, 720)), "Assertion on")
})

test_that("pdf_clip_path_close is idempotent", {
  cp <- pdf_clip_path_new(c(0, 0, 100, 100))
  pdf_clip_path_close(cp)
  expect_silent(pdf_clip_path_close(cp))
})

test_that("pdf_page_insert_clip_path transfers ownership", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  cp <- pdf_clip_path_new(c(72, 72, 540, 720))
  expect_true(pdfium:::cpp_handle_is_valid(cp$ptr))
  ret <- pdf_page_insert_clip_path(page, cp)
  expect_identical(ret, doc)
  # After insert, the externalptr is cleared (page owns the path).
  expect_false(pdfium:::cpp_handle_is_valid(cp$ptr))
})

test_that("pdf_page_insert_clip_path refuses a closed clip box", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  cp <- pdf_clip_path_new(c(0, 0, 50, 50))
  pdf_clip_path_close(cp)
  expect_error(pdf_page_insert_clip_path(page, cp),
               "Clip-path handle has been closed")
})

test_that("pdf_obj_transform_clip_path runs on a rect with a clip", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  rect <- pdf_rect_new(page, 0, 0, 100, 100)
  # No prior clip path; TransformClipPath is still safe to call.
  ret <- pdf_obj_transform_clip_path(rect, c(1, 0, 0, 1, 10, 20))
  expect_identical(ret, doc)
})

test_that("pdf_page_transform_with_clip works on a fixture page", {
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  ret <- pdf_page_transform_with_clip(page, c(1, 0, 0, 1, 0, 0),
                                        c(0, 0, 612, 792))
  expect_identical(ret, doc)
})

test_that("pdf_page_transform_with_clip validates matrix shape", {
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(pdf_page_transform_with_clip(page, c(1, 0, 0)),
               "Assertion on")
})

# =========================================================================
# Phase G — system font integration
# =========================================================================

test_that("pdf_system_fonts_default_ttf_map returns a tibble", {
  m <- pdf_system_fonts_default_ttf_map()
  expect_s3_class(m, "tbl_df")
  expect_named(m, c("charset", "fontname"))
  expect_gt(nrow(m), 0L)
  expect_true(all(nzchar(m$fontname)))
})

test_that("pdf_system_fonts_install_default returns TRUE on supported platforms", {
  ok <- pdf_system_fonts_install_default()
  expect_true(isTRUE(ok))
})

# =========================================================================
# Phase E — image-bitmap embedding
# =========================================================================

test_that("pdf_bitmap_new + close round-trip", {
  bm <- pdf_bitmap_new(32L, 16L, alpha = TRUE)
  expect_s3_class(bm, "pdfium_image_buffer")
  expect_match(format(bm), "32x16")
  expect_match(format(bm), "BGRA")
  pdf_bitmap_close(bm)
  expect_silent(pdf_bitmap_close(bm))
})

test_that("pdf_bitmap_info reports the expected dims + format", {
  bm <- pdf_bitmap_new(40L, 20L, alpha = TRUE)
  on.exit(pdf_bitmap_close(bm), add = TRUE)
  info <- pdf_bitmap_info(bm)
  expect_identical(info$width, 40L)
  expect_identical(info$height, 20L)
  expect_identical(info$stride, 40L * 4L)
  # Format 4 = BGRA per fpdfview.h.
  expect_identical(info$format, 4L)
})

test_that("pdf_bitmap_fill_rect fills the pixel data", {
  bm <- pdf_bitmap_new(4L, 4L, alpha = TRUE)
  on.exit(pdf_bitmap_close(bm), add = TRUE)
  # 0xFFFF0000 = opaque red. FillRect writes BGRA so the buffer
  # should contain 00 00 FF FF per pixel.
  pdf_bitmap_fill_rect(bm, 0L, 0L, 4L, 4L, 0xFFFF0000)
  buf <- pdf_bitmap_buffer(bm)
  expect_length(buf, 4L * 4L * 4L)
  # First pixel: B=0x00, G=0x00, R=0xFF, A=0xFF
  expect_identical(buf[1L:4L], as.raw(c(0x00, 0x00, 0xFF, 0xFF)))
})

test_that("pdf_bitmap_set_buffer round-trips through buffer reads", {
  bm <- pdf_bitmap_new(2L, 2L, alpha = TRUE)
  on.exit(pdf_bitmap_close(bm), add = TRUE)
  info <- pdf_bitmap_info(bm)
  n <- info$stride * info$height
  data <- as.raw(seq_len(n) %% 256L)
  pdf_bitmap_set_buffer(bm, data)
  expect_identical(pdf_bitmap_buffer(bm), data)
})

test_that("pdf_bitmap_set_buffer validates length", {
  bm <- pdf_bitmap_new(2L, 2L, alpha = TRUE)
  on.exit(pdf_bitmap_close(bm), add = TRUE)
  expect_error(pdf_bitmap_set_buffer(bm, raw(3L)),
               "does not match")
})

test_that("pdf_image_set_bitmap attaches a bitmap to an image obj", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  bm <- pdf_bitmap_new(16L, 16L, alpha = TRUE)
  pdf_bitmap_fill_rect(bm, 0L, 0L, 16L, 16L, 0xFF00FF00)  # opaque green

  # pdf_image_new currently requires JPEG bytes; create a minimal
  # JPEG to seed the image-obj. Then pdf_image_set_bitmap replaces
  # the JPEG content with the bitmap.
  jp <- tempfile(fileext = ".jpg")
  grDevices::jpeg(jp, width = 64, height = 64)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  graphics::rect(0, 0, 1, 1, col = "red", border = NA)
  grDevices::dev.off()
  img <- pdf_image_new(page, jp, bounds = c(0, 0, 100, 100))
  ret <- pdf_image_set_bitmap(img, bm)
  expect_identical(ret, doc)
  pdf_bitmap_close(bm)  # safe — PDFium has copied
})

# =========================================================================
# Phase D — form-XObject / page-merge extras
# =========================================================================

test_that("pdf_xobject_from_page + pdf_obj_form_from_xobject round-trip", {
  src <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(src), add = TRUE)
  dest <- pdf_doc_new()
  on.exit(pdf_doc_close(dest), add = TRUE)
  page <- pdf_page_new(dest, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  xo <- pdf_xobject_from_page(dest, src, 1L)
  expect_s3_class(xo, "pdfium_xobject")
  form <- pdf_obj_form_from_xobject(page, xo)
  expect_s3_class(form, "pdfium_obj")
  expect_identical(form$type, "form")
  # Closing the XObject after instantiating doesn't kill the form.
  pdf_xobject_close(xo)
  expect_silent(pdf_xobject_close(xo))  # idempotent
})

test_that("pdf_obj_form_from_xobject refuses a closed xobject", {
  src <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(src), add = TRUE)
  dest <- pdf_doc_new()
  on.exit(pdf_doc_close(dest), add = TRUE)
  page <- pdf_page_new(dest, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  xo <- pdf_xobject_from_page(dest, src, 1L)
  pdf_xobject_close(xo)
  expect_error(pdf_obj_form_from_xobject(page, xo),
               "XObject handle has been closed")
})

test_that("pdf_docs_import_pages with explicit range works", {
  src <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(src), add = TRUE)
  src_n <- pdf_page_count(src)
  dest <- pdf_doc_new()
  on.exit(pdf_doc_close(dest), add = TRUE)
  pdf_docs_import_pages(dest, src, range = "1")
  expect_equal(pdf_page_count(dest), 1L)
})

test_that("pdf_docs_import_pages with empty range imports everything", {
  src <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(src), add = TRUE)
  src_n <- pdf_page_count(src)
  dest <- pdf_doc_new()
  on.exit(pdf_doc_close(dest), add = TRUE)
  pdf_docs_import_pages(dest, src, range = "")
  expect_equal(pdf_page_count(dest), src_n)
})

test_that("pdf_annot_add_file_attachment returns a pdfium_attachment", {
  s <- annot_blank_page()
  a <- pdf_annot_new(s$page, "fileattachment",
                       bounds = c(0, 0, 50, 50))
  att <- pdf_annot_add_file_attachment(a, "data.bin")
  expect_s3_class(att, "pdfium_attachment")
})
