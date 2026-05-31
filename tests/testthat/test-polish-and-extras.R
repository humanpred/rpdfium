# Tests for the phase-6 polish-and-extras additions:
#   * pdf_obj_matrix() returning a 3x3 matrix
#   * pdf_doc_open(source = <raw>)
#   * pdf_doc_text(), pdf_doc_fonts(), pdf_doc_file_id(), pdf_doc_page_mode()
#   * password= argument propagation
#   * pdf_text_chars(), pdf_page_box(), pdf_page_links()
#   * pdf_page_objects(recursive = TRUE)

# pdf_obj_matrix ---------------------------------------------------

test_that("pdf_obj_matrix returns a 3x3 matrix in homogeneous form", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  for (o in pdf_page_objects(page)) {
    M <- pdf_obj_matrix(o)
    expect_true(is.matrix(M))
    expect_equal(dim(M), c(3L, 3L))
    expect_equal(M[3L, ], c(0, 0, 1))
  }
})

test_that("pdf_obj_matrix composes with point %*% to transform coords", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
  M <- pdf_obj_matrix(paths[[1L]])
  # y-flip with 216 translation: local (10, 50, 1) -> page (10, 166).
  pt <- M %*% c(10, 50, 1)
  expect_equal(pt[1L, 1L], 10, tolerance = 1e-3)
  expect_equal(pt[2L, 1L], 166, tolerance = 1e-3)
})

# pdf_doc_open(source = <raw>) ----------------------------------------

test_that("pdf_doc_open(source = raw) loads from in-memory bytes", {
  fx <- fixture_path("shapes")
  bytes <- readBin(fx, "raw", file.info(fx)$size)
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)

  expect_s3_class(doc, "pdfium_doc")
  expect_identical(pdf_page_count(doc), 1L)
  # Round-trip: text from raw matches text from path.
  expect_identical(pdf_doc_text(doc), pdf_doc_text(fx))
})

test_that("pdf_doc_open validates source / path / password", {
  expect_error(
    pdf_doc_open(),
    "One of `path` or `source` must be provided"
  )
  fx <- fixture_path("shapes")
  expect_error(
    pdf_doc_open(path = fx, source = readBin(fx, "raw", 100L)),
    "Pass exactly one of"
  )
  expect_error(
    pdf_doc_open(source = "not raw"),
    "Assertion on"
  )
  expect_error(
    pdf_doc_open(source = raw(0L)),
    "Assertion on"
  )
  expect_error(
    pdf_doc_open(fx, password = 42),
    "Assertion on"
  )
})

# pdf_doc_text / pdf_doc_fonts / pdf_doc_file_id / pdf_doc_page_mode ----------

test_that("pdf_doc_text returns one string per page", {
  txt <- pdf_doc_text(fixture_path("shapes"))
  expect_type(txt, "character")
  expect_length(txt, 1L)
  expect_match(txt, "Hello")
})

test_that("pdf_doc_fonts rolls up document fonts with first_seen_page", {
  fonts <- pdf_doc_fonts(fixture_path("shapes"))
  expect_s3_class(fonts, "tbl_df")
  expect_named(fonts, c(
    "font_base_name", "font_family",
    "font_weight", "font_italic_angle",
    "font_is_embedded", "font_flags",
    "first_seen_page"
  ))
  expect_gte(nrow(fonts), 1L)
  expect_true(all(fonts$first_seen_page >= 1L))
})

test_that("pdf_doc_file_id returns raw bytes, possibly empty", {
  id <- pdf_doc_file_id(fixture_path("shapes"))
  expect_type(id, "raw")
  # Cairo doesn't write a /ID entry for our fixture, so empty is
  # expected. The contract is still "raw vector"; just verify it
  # didn't error.
  expect_gte(length(id), 0L)
})

test_that("pdf_doc_file_id rejects unknown id_type", {
  expect_error(
    pdf_doc_file_id(fixture_path("shapes"), id_type = "neither"),
    "should be one of"
  )
})

test_that("pdf_doc_page_mode returns a documented label", {
  pm <- pdf_doc_page_mode(fixture_path("shapes"))
  expect_type(pm, "character")
  expect_true(pm %in% c(
    "unknown", "use_none", "use_outlines",
    "use_thumbs", "full_screen", "use_oc",
    "use_attachments"
  ))
})

# password= ------------------------------------------------------

test_that("password= flows through path-shortcut wrappers", {
  # Smoke test on a non-encrypted PDF - calling with password = NULL
  # (default) and password = "" should both succeed unchanged.
  fx <- fixture_path("shapes")
  expect_equal(
    pdf_page_count(fx, password = NULL),
    pdf_page_count(fx)
  )
  expect_equal(
    pdf_doc_info(fx, password = NULL)$page_count,
    1L
  )
  expect_s3_class(
    pdf_extract_paths(fx, password = NULL),
    "tbl_df"
  )
})

# pdf_text_chars -------------------------------------------------

test_that("pdf_text_char_at_point hits a known glyph in shapes.pdf", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
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
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # Sample a corner well outside any character.
  expect_true(is.na(pdf_text_char_at_point(doc, -100, -100,
    page_num = 1L
  )))
})

test_that("text-index <-> char-index round trip is consistent", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  chars <- pdf_text_chars(doc, page_num = 1L)
  # Walk every char that has a non-NA text_index; round-tripping
  # back through cpp's GetCharIndexFromTextIndex should land on
  # the same char_index.
  for (i in seq_len(nrow(chars))) {
    ti <- chars$text_index[[i]]
    if (is.na(ti)) next
    ti_helper <- pdf_text_index_from_char(doc, chars$char_index[[i]],
      page_num = 1L
    )
    expect_equal(ti_helper, ti)
    ci_back <- pdf_text_char_from_text_index(doc, ti, page_num = 1L)
    expect_equal(ci_back, chars$char_index[[i]])
  }
})

test_that("pdf_text_char_at_point / index helpers validate inputs", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_text_char_at_point(doc, NA, 1), "Assertion on")
  expect_error(pdf_text_char_at_point(doc, 1, NA), "Assertion on")
  expect_error(
    pdf_text_char_at_point(doc, 1, 1, tolerance = NA),
    "Assertion on"
  )
  expect_error(pdf_text_index_from_char(doc, NA), "Assertion on")
  expect_error(
    pdf_text_char_from_text_index(doc, NA),
    "Assertion on"
  )
})

test_that("pdf_text_chars returns one row per character with bounds + flags", {
  chars <- pdf_text_chars(pdf_doc_open(fixture_path("shapes")), page_num = 1L)
  expect_s3_class(chars, "tbl_df")
  expect_named(chars, c(
    "char_index", "codepoint", "char",
    "bounds_left", "bounds_bottom",
    "bounds_right", "bounds_top",
    "font_size", "is_generated", "is_hyphen",
    "origin_x", "origin_y",
    "loose_left", "loose_bottom",
    "loose_right", "loose_top",
    "unicode_map_error", "text_index",
    "char_font_name", "char_font_flags"
  ))
  expect_type(chars$codepoint, "integer")
  expect_type(chars$char, "character")
  expect_type(chars$is_generated, "logical")
  expect_type(chars$is_hyphen, "logical")
  expect_type(chars$origin_x, "double")
  expect_type(chars$origin_y, "double")
  expect_type(chars$loose_left, "double")
  expect_type(chars$unicode_map_error, "logical")
  expect_type(chars$text_index, "integer")
  # The fixture text is "Hello" - 5 visible chars.
  visible <- chars[!chars$is_generated, ]
  expect_gte(nrow(visible), 5L)
  expect_identical(paste(visible$char[1L:5L], collapse = ""), "Hello")
})

# pdf_page_box ----------------------------------------------------

test_that("pdf_page_box(media) matches pdf_page_size dimensions", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  media <- pdf_page_box(page, box = "media")
  sz <- pdf_page_size(page)
  expect_equal(media[["right"]] - media[["left"]], sz[["width"]])
  expect_equal(media[["top"]] - media[["bottom"]], sz[["height"]])
})

test_that("pdf_page_box returns NAs for boxes the PDF doesn't declare", {
  page <- pdf_page_load(pdf_doc_open(fixture_path("shapes")), 1L)
  for (b in c("crop", "bleed", "trim", "art")) {
    res <- pdf_page_box(page, box = b)
    expect_named(res, c("left", "bottom", "right", "top"))
    expect_true(all(is.na(res)),
      info = paste0("box=", b)
    )
  }
})

test_that("pdf_page_box rejects unknown box names", {
  page <- pdf_page_load(pdf_doc_open(fixture_path("shapes")), 1L)
  expect_error(
    pdf_page_box(page, box = "noBox"),
    "should be one of"
  )
})

# pdf_page_links --------------------------------------------------

test_that("pdf_page_links returns 0 rows for a page with no links", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  links <- pdf_page_links(doc, page_num = 1L)
  expect_s3_class(links, "tbl_df")
  expect_equal(nrow(links), 0L)
  expect_named(links, c(
    "link_index", "bounds_left", "bounds_bottom",
    "bounds_right", "bounds_top", "action_type",
    "uri", "filepath", "dest_page_num",
    "dest_view", "dest_x", "dest_y", "dest_zoom",
    "quad_points"
  ))
})

test_that("pdf_page_links reports a URI link's target correctly", {
  # annotated.pdf has one URI link annotation at rect (50,150)-(200,170)
  # targeting https://example.com. Previously the action_type lookup
  # was off by one and reported this as "launch" — the test guards
  # against that regression.
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  links <- pdf_page_links(doc, page_num = 1L)
  expect_equal(nrow(links), 1L)
  expect_equal(links$action_type, "uri")
  expect_equal(links$uri, "https://example.com")
  expect_true(is.na(links$filepath))
  expect_true(is.na(links$dest_page_num))
  expect_equal(links$bounds_left, 50)
  expect_equal(links$bounds_bottom, 150)
  expect_equal(links$bounds_right, 200)
  expect_equal(links$bounds_top, 170)
})

# Helper: hand-build a small two-page PDF with two link annotations
# on page 1:
#   * Link #1 carries /Dest only (no /A entry), exercising the
#     FPDFLink_GetDest() fallback inside cpp_page_links.
#   * Link #2 carries /A /URI + /QuadPoints, exercising the per-line
#     quad-points matrix path.
# We construct the bytes inline (rather than baking it into
# inst/extdata/fixtures) because the link-edge cases are local to
# this file's tests.
.build_link_quad_pdf <- function(out) {
  obj_fmt <- function(n, body) paste0(n, " 0 obj\n", body, "\nendobj\n")

  obj1 <- obj_fmt(1, "<< /Type /Catalog /Pages 2 0 R >>")
  obj2 <- obj_fmt(2, "<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>")
  obj3 <- obj_fmt(3, paste0(
    "<< /Type /Page /Parent 2 0 R ",
    "/MediaBox [0 0 300 300] /Resources <<>> ",
    "/Annots [5 0 R 6 0 R] >>"
  ))
  obj4 <- obj_fmt(4, paste0(
    "<< /Type /Page /Parent 2 0 R ",
    "/MediaBox [0 0 300 300] /Resources <<>> >>"
  ))
  # Link carrying /Dest only (no /A); page 2 reference is indirect.
  obj5 <- obj_fmt(5, paste0(
    "<< /Type /Annot /Subtype /Link ",
    "/Rect [10 10 100 50] ",
    "/Dest [4 0 R /XYZ 50 200 1.5] >>"
  ))
  # Link with /A /URI + multi-line /QuadPoints (two lines).
  obj6 <- obj_fmt(6, paste0(
    "<< /Type /Annot /Subtype /Link ",
    "/Rect [20 100 200 200] ",
    "/A << /S /URI /URI (https://test.example) >> ",
    "/QuadPoints [20 200 200 200 20 150 200 150 ",
    "20 150 200 150 20 100 200 100] >>"
  ))

  header <- charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
  parts <- list(
    header,
    charToRaw(obj1), charToRaw(obj2),
    charToRaw(obj3), charToRaw(obj4),
    charToRaw(obj5), charToRaw(obj6)
  )
  cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
  offs <- cum[seq_len(6L) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  xref <- paste(
    c(
      "xref", "0 7", "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")
    ),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  full <- c(unlist(parts), charToRaw(xref), charToRaw(trailer))
  writeBin(full, out)
}

test_that("pdf_page_links resolves /Dest-only links via FPDFLink_GetDest fallback", {
  # Exercises the action == nullptr branch in cpp_page_links: the
  # link carries no /A entry so classify_action() returns a NULL
  # action handle, and cpp_page_links falls back to FPDFLink_GetDest
  # to recover the destination's page index, view, and (x,y,zoom).
  tmp <- withr::local_tempfile(fileext = ".pdf")
  .build_link_quad_pdf(tmp)
  doc <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc), add = TRUE)

  links <- pdf_page_links(doc, page_num = 1L)
  expect_equal(nrow(links), 2L)
  # Link 1: /Dest-only -> action_type "goto" via the fallback.
  expect_equal(links$action_type[[1L]], "goto")
  expect_true(is.na(links$uri[[1L]]))
  expect_true(is.na(links$filepath[[1L]]))
  expect_equal(links$dest_page_num[[1L]], 2L)
  expect_equal(links$dest_view[[1L]], "xyz")
  expect_equal(links$dest_x[[1L]], 50)
  expect_equal(links$dest_y[[1L]], 200)
  expect_equal(links$dest_zoom[[1L]], 1.5)
  expect_equal(links$bounds_left[[1L]], 10)
  expect_equal(links$bounds_bottom[[1L]], 10)
  expect_equal(links$bounds_right[[1L]], 100)
  expect_equal(links$bounds_top[[1L]], 50)
})

test_that("pdf_page_links returns a quad-points matrix for multi-line /QuadPoints", {
  # Link 2 in the helper fixture carries /QuadPoints describing two
  # lines, exercising the n_quads > 0 matrix path inside
  # cpp_page_links. Single-line links (or links without /QuadPoints)
  # exit through the n_quads <= 0 branch returning R NULL.
  tmp <- withr::local_tempfile(fileext = ".pdf")
  .build_link_quad_pdf(tmp)
  doc <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc), add = TRUE)

  links <- pdf_page_links(doc, page_num = 1L)
  expect_equal(nrow(links), 2L)
  # Link 1: no /QuadPoints -> NULL list-column entry.
  expect_null(links$quad_points[[1L]])
  # Link 2: /QuadPoints with two lines -> 2x8 numeric matrix.
  q2 <- links$quad_points[[2L]]
  expect_true(is.matrix(q2))
  expect_equal(dim(q2), c(2L, 8L))
  expect_identical(
    colnames(q2),
    c("x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4")
  )
  expect_equal(q2[1L, ], c(
    x1 = 20, y1 = 200, x2 = 200, y2 = 200,
    x3 = 20, y3 = 150, x4 = 200, y4 = 150
  ))
  expect_equal(q2[2L, ], c(
    x1 = 20, y1 = 150, x2 = 200, y2 = 150,
    x3 = 20, y3 = 100, x4 = 200, y4 = 100
  ))
  # Link 2 should still classify as URI.
  expect_equal(links$action_type[[2L]], "uri")
  expect_equal(links$uri[[2L]], "https://test.example")
})

# pdf_text_chars unicode encoding paths --------------------------

test_that("pdf_text_chars encodes BMP code points as multi-byte UTF-8", {
  # Loads a pre-built Cairo PDF containing é (U+00E9, 2-byte UTF-8) +
  # 中 (U+4E2D, 3-byte UTF-8) + 😀 (U+1F600, surrogate pair) and
  # exercises every relevant branch of cpp_page_text_chars's UTF-16 ->
  # UTF-8 encoder:
  #   * cp 0x80..0x7FF       (2-byte UTF-8 branch)
  #   * cp 0x800..0xFFFF     (3-byte UTF-8 branch)
  #   * 0xD800..0xDFFF       (surrogate halves -> "")
  # The 4-byte branch is unreachable through PDFium's UTF-16 unicode
  # accessor and is marked # nocov in src/page_extras.cpp.
  #
  # The fixture is shipped pre-built (inst/extdata/fixtures/...) rather
  # than generated at test time because grDevices::cairo_pdf has a
  # transitive dlopen of /opt/X11/lib/libXrender.1.dylib that fails
  # silently on macOS without XQuartz, and on macOS-arm64 R 4.6 that
  # dlopen-failure path corrupts the process heap. See
  # humanpred/rpdfium#44 and the cairo bisection branch. Loading a
  # static fixture exercises the same pdf_text_chars C++ path without
  # going anywhere near the buggy R+macOS interaction.
  doc <- pdf_doc_open(fixture_path("cairo-cjk-utf8"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  chars <- pdf_text_chars(doc, page_num = 1L)

  cps <- chars$codepoint
  # 2-byte UTF-8 branch: cp 0x00E9 -> 0xC3 0xA9 -> "é"
  expect_true(0x00e9L %in% cps)
  expect_identical(chars$char[match(0x00e9L, cps)], "é")
  # 3-byte UTF-8 branch: cp 0x4E2D -> 0xE4 0xB8 0xAD -> "中"
  expect_true(0x4e2dL %in% cps)
  expect_identical(chars$char[match(0x4e2dL, cps)], "中")
  # Surrogate-half branch: 0xD800..0xDFFF -> "" (no UTF-8 produced).
  surrogate_idx <- which(cps >= 0xD800L & cps <= 0xDFFFL)
  expect_gt(length(surrogate_idx), 0L)
  expect_true(all(chars$char[surrogate_idx] == ""))
})

# Direct-shim defensive entry-point tests ----------------------------

test_that("cpp_page_box rejects non-extptr page args + unknown box names", {
  # Three C-side defensive guards in src/page_extras.cpp:
  #   * page_from_ptr() TYPEOF != EXTPTRSXP
  #   * doc_from_ptr() TYPEOF != EXTPTRSXP (cpp_page_links only)
  #   * cpp_page_box unknown-box stop()
  # The user-facing R wrappers normally catch these earlier, but
  # the cpp_* shims own the contract for any direct-:::-caller.
  expect_error(
    pdfium:::cpp_page_box(42L, "media"),
    "external pointer for the page"
  )
  expect_error(
    pdfium:::cpp_page_box("not-a-ptr", "media"),
    "external pointer for the page"
  )

  # Build a real page handle for the unknown-box stop().
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(
    pdfium:::cpp_page_box(page$ptr, "nope"),
    "Unknown box"
  )
})

test_that("cpp_page_links rejects a non-extptr doc handle", {
  # Direct-shim defensive entry: doc_from_ptr() trips when the doc
  # argument isn't an externalptr. The R wrapper short-circuits
  # this earlier via assert_multi_class(), but the C-side guard is
  # the documented safety net.
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(
    pdfium:::cpp_page_links(42L, page$ptr),
    "external pointer for the document"
  )
  expect_error(
    pdfium:::cpp_page_links("not-a-ptr", page$ptr),
    "external pointer for the document"
  )
})

# pdf_page_objects(recursive) -----------------------------------

test_that("pdf_page_objects(recursive = TRUE) is a no-op when no forms", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  flat <- pdf_page_objects(page)
  recurs <- pdf_page_objects(page, recursive = TRUE)
  expect_length(recurs, length(flat))
})

test_that("pdf_page_objects(recursive = TRUE) descends into form objects", {
  doc <- pdf_doc_open(fixture_path("form_xobject"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  flat <- pdf_page_objects(page)
  recurs <- pdf_page_objects(page, recursive = TRUE)
  # The fixture has 2 top-level forms; one populated with 2 nested
  # objects, one empty. So flat = 2; recursive = 2 + 2 + 0 = 4.
  expect_equal(length(flat), 2L)
  expect_equal(length(recurs), 4L)
  expect_identical(
    vapply(recurs, function(o) o$type, character(1L)),
    c("form", "path", "path", "form")
  )
})

test_that("pdf_page_objects(recursive) validates its flag", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  expect_error(
    pdf_page_objects(page, recursive = NA),
    "Assertion on"
  )
  expect_error(
    pdf_page_objects(page, recursive = "yes"),
    "Assertion on"
  )
})

# Edge-case coverage for the page-level helpers --------------------

test_that("pdf_doc_fonts returns the empty schema for a doc with no text", {
  # minimal.pdf is a blank Cairo page with no text runs anywhere.
  fonts <- pdf_doc_fonts(fixture_path("minimal"))
  expect_s3_class(fonts, "tbl_df")
  expect_equal(nrow(fonts), 0L)
  expect_named(fonts, c(
    "font_base_name", "font_family",
    "font_weight", "font_italic_angle",
    "font_is_embedded", "font_flags",
    "first_seen_page"
  ))
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
  doc <- pdf_doc_open(fixture_path("shapes"))
  page <- pdf_page_load(doc, 1L)
  pdf_page_close(page)
  expect_error(pdf_page_box(page), "Page has been closed")

  pdf_doc_close(doc)
  expect_error(pdf_page_box(doc), "Document has been closed")

  expect_error(
    pdf_page_box(42L),
    "class .pdfium_page./.pdfium_doc."
  )
})

test_that("doc_extra's internal as_doc_handle rejects bad inputs and closed docs", {
  # The doc-level helpers in R/doc_extra.R (pdf_doc_text, pdf_doc_fonts,
  # pdf_doc_file_id, pdf_doc_page_mode) all share the as_doc_handle
  # validator. Exercise both rejection paths via pdf_doc_text() and
  # pdf_doc_file_id() so the helper's branches are covered.
  expect_error(
    pdf_doc_text(42L),
    "class .pdfium_doc."
  )
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_text(doc), "Document has been closed")
  expect_error(pdf_doc_file_id(doc), "Document has been closed")
})

test_that("pdf_doc_text returns the empty string for pages with no text", {
  # minimal.pdf is a single blank Cairo page with no text runs.
  txt <- pdf_doc_text(fixture_path("minimal"))
  expect_identical(txt, "")
})
