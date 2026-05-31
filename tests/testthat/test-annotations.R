# Tests for pdf_annotations() (now returns a `pdfium_annot_list`)
# and its `as_tibble()` companion. annotated.pdf is a hand-built
# fixture with five annotations on page 1:
#   1. text     /Rect [20 250 40 270]  /Contents="Hello" /T="Alice"
#   2. highlight /Rect [50 200 200 220]
#   3. link     /Rect [50 150 200 170]  (URI -> example.com)
#   4. widget   /Rect [50 100 200 120]  (form text field, name="name")
#   5. widget   /Rect [50  60  70  80]  (form checkbox,  name="agree")

test_that("pdf_annotations returns 0 handles for a page with no annots", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  res <- pdf_annotations(page)
  expect_s3_class(res, "pdfium_annot_list")
  expect_length(res, 0L)
  tbl <- tibble::as_tibble(res)
  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 0L)
  expect_named(tbl, c(
    "annotation_index", "subtype_code", "subtype",
    "flags", "is_invisible", "is_hidden", "is_print",
    "is_no_view", "is_read_only", "is_locked",
    "bounds_left", "bounds_bottom",
    "bounds_right", "bounds_top",
    "contents", "title", "subject",
    "color_red", "color_green", "color_blue",
    "color_alpha", "interior_red", "interior_green",
    "interior_blue", "interior_alpha",
    "border_width",
    "quad_points", "vertices", "ink_paths",
    "font_color_red", "font_color_green",
    "font_color_blue", "font_size",
    "popup_index", "irt_index",
    "file_attachment_name",
    "handle", "source"
  ))
})

test_that("pdf_annotations populates quad_points / vertices / ink_paths", {
  doc <- pdf_doc_open(fixture_path("annot_geom"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(nrow(res), 3L)
  # The polygon row has /Vertices but no quads or ink.
  poly <- res[res$subtype == "polygon", ]
  expect_equal(nrow(poly), 1L)
  expect_true(is.null(poly$quad_points[[1L]]))
  expect_true(is.null(poly$ink_paths[[1L]]))
  v <- poly$vertices[[1L]]
  expect_true(is.matrix(v))
  expect_equal(dim(v), c(3L, 2L))
  expect_equal(v[1L, ], c(x = 10, y = 10))
  expect_equal(v[2L, ], c(x = 60, y = 10))
  expect_equal(v[3L, ], c(x = 35, y = 60))

  # The ink row has /InkList with two strokes.
  ink <- res[res$subtype == "ink", ]
  expect_true(is.null(ink$quad_points[[1L]]))
  expect_true(is.null(ink$vertices[[1L]]))
  paths <- ink$ink_paths[[1L]]
  expect_type(paths, "list")
  expect_length(paths, 2L)
  expect_equal(dim(paths[[1L]]), c(3L, 2L))
  expect_equal(dim(paths[[2L]]), c(2L, 2L))
  expect_equal(paths[[2L]][1L, ], c(x = 120, y = 180))

  # The two-line highlight has /QuadPoints with two quad sets.
  hl <- res[res$subtype == "highlight", ]
  expect_true(is.null(hl$vertices[[1L]]))
  expect_true(is.null(hl$ink_paths[[1L]]))
  q <- hl$quad_points[[1L]]
  expect_true(is.matrix(q))
  expect_equal(dim(q), c(2L, 8L))
  expect_equal(
    colnames(q),
    c("x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4")
  )
  expect_equal(
    q[1L, ],
    c(
      x1 = 50, y1 = 290, x2 = 250, y2 = 290,
      x3 = 50, y3 = 270, x4 = 250, y4 = 270
    )
  )
})

test_that("pdfium_annot_subtype_code round-trips with the name helper", {
  codes <- 0L:9L
  names <- pdfium:::annotation_subtype_name(codes)
  back <- pdfium:::pdfium_annot_subtype_code(names)
  expect_identical(back, codes)
  # Unknown / NA -> 0L (UNKNOWN).
  expect_identical(
    pdfium:::pdfium_annot_subtype_code(c("bogus", NA)),
    c(0L, 0L)
  )
})

test_that("pdf_annotations reads color and subject when set", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  # Highlight annot (annotation_index 2) carries /C [0.9 0.9 0.2]
  # and /Subj (Important) per the fixture.
  hl <- res[res$subtype == "highlight", ]
  expect_equal(nrow(hl), 1L)
  expect_equal(hl$color_red[[1L]], 229 / 255, tolerance = 1e-3)
  expect_equal(hl$color_green[[1L]], 229 / 255, tolerance = 1e-3)
  expect_equal(hl$color_blue[[1L]], 51 / 255, tolerance = 1e-3)
  expect_equal(hl$color_alpha[[1L]], 1.0)
  expect_equal(hl$subject[[1L]], "Important")
  # Annots without /C come back as NA (no fallback to appearance
  # stream — see read_annot_color in src/annotations.cpp).
  txt <- res[res$subtype == "text", ]
  expect_true(is.na(txt$color_red[[1L]]))
  expect_true(is.na(txt$color_alpha[[1L]]))
})

test_that("pdf_annotations decodes the universal /F flag bits", {
  # Bits 1, 2, 3, 6, 7, 8 decode independently; annotated.pdf has
  # no /F set on any annot so all flags should be FALSE.
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_true(all(!res$is_invisible))
  expect_true(all(!res$is_hidden))
  expect_true(all(!res$is_print))
  expect_true(all(!res$is_no_view))
  expect_true(all(!res$is_read_only))
  expect_true(all(!res$is_locked))
  # Direct unit-test the decoder so a single fixture doesn't have
  # to cover every bit.
  expect_identical(
    pdfium:::annot_flag_decode(c(0L, 1L, 4L, 64L, 128L), 1L),
    c(FALSE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_identical(
    pdfium:::annot_flag_decode(c(0L, 1L, 4L, 64L, 128L), 3L),
    c(FALSE, FALSE, TRUE, FALSE, FALSE)
  )
  expect_identical(
    pdfium:::annot_flag_decode(c(0L, 1L, 4L, 64L, 128L), 8L),
    c(FALSE, FALSE, FALSE, FALSE, TRUE)
  )
})

test_that("pdf_annotations enumerates the documented annots", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(nrow(res), 5L)
  expect_identical(res$annotation_index, 1L:5L)
  expect_identical(
    res$subtype,
    c("text", "highlight", "link", "widget", "widget")
  )
})

test_that("pdf_annotations surfaces the text annotation's strings", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_identical(res$contents[[1L]], "Hello")
  expect_identical(res$title[[1L]], "Alice")
})

test_that("pdf_annotations reads the rectangles", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(res$bounds_left[[1L]], 20)
  expect_equal(res$bounds_bottom[[1L]], 250)
  expect_equal(res$bounds_right[[1L]], 40)
  expect_equal(res$bounds_top[[1L]], 270)
  expect_equal(res$bounds_left[[3L]], 50) # link
  expect_equal(res$bounds_right[[3L]], 200)
})

test_that("pdf_annotations accepts an open page directly", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  by_page <- tibble::as_tibble(pdf_annotations(page))
  by_doc <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  # Drop handle + source columns because the live R objects differ
  # between calls; the underlying data should match.
  drop_handle <- function(t) t[, !names(t) %in% c("handle", "source")]
  expect_identical(drop_handle(by_page), drop_handle(by_doc))
})

test_that("pdf_annotations rejects bad inputs", {
  expect_error(
    pdf_annotations("not a page"),
    "class .pdfium_page./.pdfium_doc."
  )
  expect_error(
    pdf_annotations(42),
    "class .pdfium_page./.pdfium_doc."
  )
})

test_that("pdf_annotations refuses a closed page handle", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  page <- pdf_page_load(doc, 1L)
  pdf_page_close(page)
  expect_error(pdf_annotations(page), "Page has been closed")
  pdf_doc_close(doc)
})

# Helper: assemble a tiny single-page PDF from object-body strings or
# raw vectors. Each entry of `objs` is either a character scalar (object
# body wrapped automatically in `N 0 obj\n...\nendobj\n`) or a raw
# vector (treated verbatim — used for stream objects that need explicit
# `/Length` accounting).
build_inline_pdf <- function(objs) {
  obj <- function(n, body) paste0(n, " 0 obj\n", body, "\nendobj\n")
  parts <- list(charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n"))
  for (i in seq_along(objs)) {
    if (is.character(objs[[i]])) {
      parts[[i + 1L]] <- charToRaw(obj(i, objs[[i]]))
    } else {
      parts[[i + 1L]] <- objs[[i]]
    }
  }
  cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
  offs <- cum[seq_along(objs) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  size <- length(objs) + 1L
  xref <- paste(
    c("xref", paste0("0 ", size),
      "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size ", size,
    " /Root 1 0 R >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  c(unlist(parts), charToRaw(xref), charToRaw(trailer))
}

# Helper: write `bytes` to a tempfile and arrange cleanup via defer.
write_temp_pdf <- function(bytes, env = parent.frame()) {
  path <- tempfile(fileext = ".pdf")
  writeBin(bytes, path)
  withr::defer(unlink(path), envir = env)
  path
}

test_that("cpp_annot_count rejects a non-extptr SEXP", {
  # Direct cpp call: hits the EXTPTRSXP guard in page_from_ptr.
  expect_error(
    pdfium:::cpp_annot_count(42L),
    "Expected an external pointer for the page"
  )
})

test_that("pdf_annotations surfaces /Popup + /IRT linked annotation indexes", {
  # Inline PDF with a sticky-note pointing at a /Popup neighbor plus
  # an /IRT (in-reply-to) edge between two text annots. Covers the
  # find_annot_index() rect-fallback path in src/annotations.cpp —
  # PDFium hands out fresh wrapper handles per call, so pointer
  # equality fails and the rect/subtype match wins.
  bytes <- build_inline_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 300 300] /Resources <<>> ",
           "/Annots [4 0 R 5 0 R 6 0 R] >>"),
    paste0("<< /Type /Annot /Subtype /Text ",
           "/Rect [20 250 40 270] ",
           "/Contents (Reply) /T (Bob) ",
           "/Popup 5 0 R /IRT 6 0 R >>"),
    paste0("<< /Type /Annot /Subtype /Popup ",
           "/Rect [50 50 200 100] >>"),
    paste0("<< /Type /Annot /Subtype /Text ",
           "/Rect [80 200 100 220] ",
           "/Contents (Original) >>")
  ))
  path <- write_temp_pdf(bytes)
  doc <- pdf_doc_open(path)
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(nrow(res), 3L)
  expect_identical(res$subtype, c("text", "popup", "text"))
  # The Text-with-reply (row 1) points at the Popup (row 2) and at
  # the earlier Text annot (row 3).
  expect_equal(res$popup_index[[1L]], 2L)
  expect_equal(res$irt_index[[1L]], 3L)
  # The Popup itself carries no /Popup or /IRT entry.
  expect_true(is.na(res$popup_index[[2L]]))
  expect_true(is.na(res$irt_index[[2L]]))
  # The Original text annot also has no /Popup or /IRT.
  expect_true(is.na(res$popup_index[[3L]]))
  expect_true(is.na(res$irt_index[[3L]]))
})

test_that("pdf_annotations surfaces a /Popup that fails to match any annot", {
  # When /Popup points at an indirect object that does NOT live in
  # the page's /Annots array, find_annot_index() scans the page and
  # returns -1, which the wrapper turns into NA_INTEGER. This drives
  # the no-match exit of the rect-fallback walk.
  bytes <- build_inline_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 300 300] /Resources <<>> ",
           "/Annots [4 0 R] >>"),
    # The /Popup reference points at obj 5, which exists but is NOT
    # in the page's /Annots array.
    paste0("<< /Type /Annot /Subtype /Text ",
           "/Rect [20 250 40 270] ",
           "/Contents (Lonely) ",
           "/Popup 5 0 R >>"),
    paste0("<< /Type /Annot /Subtype /Popup ",
           "/Rect [50 50 200 100] >>")
  ))
  path <- write_temp_pdf(bytes)
  doc <- pdf_doc_open(path)
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(nrow(res), 1L)
  expect_true(is.na(res$popup_index[[1L]]))
})

test_that("pdf_annotations reads the /FileAttachment payload name", {
  # FileAttachment annot referencing a /FS filespec. Covers the
  # FPDFAnnot_GetFileAttachment and read_attachment_name branch in
  # annotations dot cpp.
  embed <- charToRaw("hello world\n")
  obj9_head <- paste0("9 0 obj\n",
                      "<< /Type /EmbeddedFile /Subtype /text#2Fplain ",
                      "/Length ", length(embed),
                      " >>\nstream\n")
  obj9_bytes <- c(charToRaw(obj9_head), embed,
                  charToRaw("\nendstream\nendobj\n"))
  bytes <- build_inline_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 300 300] /Resources <<>> ",
           "/Annots [4 0 R 5 0 R 6 0 R 7 0 R] >>"),
    paste0("<< /Type /Annot /Subtype /Text ",
           "/Rect [20 250 40 270] ",
           "/Contents (note) >>"),
    paste0("<< /Type /Annot /Subtype /FileAttachment ",
           "/Rect [60 60 80 80] ",
           "/Contents (stickyfile) ",
           "/FS 8 0 R >>"),
    paste0("<< /Type /Annot /Subtype /FileAttachment ",
           "/Rect [100 100 120 120] ",
           "/Contents (no-fs) >>"),  # missing /FS → name comes back NA
    paste0("<< /Type /Annot /Subtype /Text ",
           "/Rect [150 150 170 170] ",
           "/Contents (other) >>"),
    paste0("<< /Type /Filespec /F (hello.txt) ",
           "/UF (hello.txt) ",
           "/EF << /F 9 0 R >> >>"),
    obj9_bytes
  ))
  path <- write_temp_pdf(bytes)
  doc <- pdf_doc_open(path)
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(nrow(res), 4L)
  expect_identical(
    res$subtype,
    c("text", "fileattachment", "fileattachment", "text")
  )
  # First fileattachment has a valid /FS pointing at hello.txt.
  expect_equal(res$file_attachment_name[[2L]], "hello.txt")
  # Second fileattachment has no /FS — name is NA.
  expect_true(is.na(res$file_attachment_name[[3L]]))
  # Non-fileattachment subtypes always come back NA.
  expect_true(is.na(res$file_attachment_name[[1L]]))
  expect_true(is.na(res$file_attachment_name[[4L]]))
})

test_that("pdf_annotations reads /Border width and /DA font color", {
  # A FreeText annot with /DA gives FPDFAnnot_GetFontColor a payload
  # to parse — exercises font_color_red/green/blue. A Line annot with
  # /Border [hr vr width] drives the FPDFAnnot_GetBorder success path.
  bytes <- build_inline_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 300 300] /Resources <<>> ",
           "/Annots [4 0 R 5 0 R] >>"),
    paste0("<< /Type /Annot /Subtype /FreeText ",
           "/Rect [10 10 100 30] ",
           "/DA (/Helv 12 Tf 1 0 0 rg) ",
           "/Contents (Hello) >>"),
    paste0("<< /Type /Annot /Subtype /Line ",
           "/Rect [50 50 150 100] ",
           "/L [50 50 150 100] ",
           "/Border [0 0 5] ",
           "/C [1 0 0] >>")
  ))
  path <- write_temp_pdf(bytes)
  doc <- pdf_doc_open(path)
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(nrow(res), 2L)
  # FreeText with red /DA — red == 1, green == 0, blue == 0.
  ft <- res[res$subtype == "freetext", ]
  expect_equal(nrow(ft), 1L)
  expect_equal(ft$font_color_red[[1L]], 1.0)
  expect_equal(ft$font_color_green[[1L]], 0.0)
  expect_equal(ft$font_color_blue[[1L]], 0.0)
  # Line annot with /Border [0 0 5] — third entry is the line width.
  ln <- res[res$subtype == "line", ]
  expect_equal(nrow(ln), 1L)
  expect_equal(ln$border_width[[1L]], 5)
})

test_that("pdf_annotations handles an Ink annot with an empty stroke", {
  # /InkList [ [] [120 180 180 180] ] — the first stroke is empty,
  # the second has two points. Exercises the n == 0 early-return
  # inside read_annot_ink_paths().
  bytes <- build_inline_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 300 300] /Resources <<>> ",
           "/Annots [4 0 R] >>"),
    paste0("<< /Type /Annot /Subtype /Ink ",
           "/Rect [100 100 200 200] ",
           "/InkList [ ",
           "  [] ",
           "  [120 180 180 180] ",
           "] >>")
  ))
  path <- write_temp_pdf(bytes)
  doc <- pdf_doc_open(path)
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- tibble::as_tibble(pdf_annotations(doc, page_num = 1L))
  expect_equal(nrow(res), 1L)
  expect_identical(res$subtype, "ink")
  paths <- res$ink_paths[[1L]]
  expect_type(paths, "list")
  expect_length(paths, 2L)
  expect_equal(dim(paths[[1L]]), c(0L, 2L))
  expect_equal(dim(paths[[2L]]), c(2L, 2L))
  expect_equal(paths[[2L]][1L, ], c(x = 120, y = 180))
})

test_that("cpp_annots_list returns NA font_color when no form-fill env", {
  # Direct cpp call: passing a non-extptr as doc_ptr means owning_doc
  # stays nullptr, FPDFDOC_InitFormFillEnvironment is skipped, and
  # every row's font_color / font_size column reads NA. Exercises the
  # `form == nullptr` branch of cpp_annots_list().
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  raw <- pdfium:::cpp_annots_list(42L, page$ptr)
  expect_true(all(is.na(raw$font_color_red)))
  expect_true(all(is.na(raw$font_color_green)))
  expect_true(all(is.na(raw$font_color_blue)))
  expect_true(all(is.na(raw$font_size)))
})

test_that("pdf_annotations tolerates annot-array references that miss objects", {
  # /Annots [99 0 R 4 0 R] — the first reference points at an object
  # that doesn't exist in the xref. FPDFPage_GetAnnot(page, 0) hands
  # back nullptr; cpp_annots_list() fills that row with NA for every
  # column. This drives the entire null-annot defensive branch.
  bytes <- build_inline_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0("<< /Type /Page /Parent 2 0 R ",
           "/MediaBox [0 0 300 300] /Resources <<>> ",
           "/Annots [99 0 R 4 0 R] >>"),
    paste0("<< /Type /Annot /Subtype /Text ",
           "/Rect [10 10 30 30] ",
           "/Contents (real) >>")
  ))
  path <- write_temp_pdf(bytes)
  doc <- pdf_doc_open(path)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  # The annot array length is two, but only one resolves.
  expect_equal(pdfium:::cpp_annot_count(page$ptr), 2L)
  raw <- pdfium:::cpp_annots_list(doc$ptr, page$ptr)
  expect_length(raw$subtype_code, 2L)
  # Row 1 is the unresolvable reference: subtype_code NA, flags NA,
  # bounds NA, strings NA, color/border NA, list-columns NULL, etc.
  expect_true(is.na(raw$subtype_code[[1L]]))
  expect_true(is.na(raw$flags[[1L]]))
  expect_true(is.na(raw$bounds_left[[1L]]))
  expect_true(is.na(raw$bounds_bottom[[1L]]))
  expect_true(is.na(raw$bounds_right[[1L]]))
  expect_true(is.na(raw$bounds_top[[1L]]))
  expect_true(is.na(raw$contents[[1L]]))
  expect_true(is.na(raw$title[[1L]]))
  expect_true(is.na(raw$subject[[1L]]))
  expect_true(is.na(raw$color_red[[1L]]))
  expect_true(is.na(raw$interior_red[[1L]]))
  expect_true(is.na(raw$border_width[[1L]]))
  expect_null(raw$quad_points[[1L]])
  expect_null(raw$vertices[[1L]])
  expect_null(raw$ink_paths[[1L]])
  expect_true(is.na(raw$font_color_red[[1L]]))
  expect_true(is.na(raw$font_size[[1L]]))
  expect_true(is.na(raw$popup_index[[1L]]))
  expect_true(is.na(raw$irt_index[[1L]]))
  expect_true(is.na(raw$file_attachment_name[[1L]]))
  # Row 2 is the real Text annot.
  expect_equal(raw$subtype_code[[2L]], 1L) # FPDF_ANNOT_TEXT
  expect_equal(raw$bounds_left[[2L]], 10)
})
