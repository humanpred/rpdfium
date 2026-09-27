# Tests targeting branches in src/annot_handles.cpp that aren't
# covered by the readers in test-annot-class.R or the authoring
# tests in test-annot-authoring.R:
#   * cpp_annot_get out-of-range error
#   * cpp_annot_delete refusing an annotation that is not on the page
#   * cpp_annot_border NA branch (annot with no /Border or /BS)
#   * cpp_annot_font_color success branch (FreeText with /DA colour)
#   * cpp_annot_has_attachment_points TRUE and FALSE branches
#   * cpp_annot_vertices_handle success branch (polygon)
#   * cpp_annot_ink_paths_handle success branch (ink)
#   * cpp_annot_linked_handle success branches (/Popup, /IRT)
#   * cpp_annot_file_attachment_name_handle success branch
#   * pdf_doc_close() closing live annotation handles (ADR-024)
#
# Inline-PDF helpers below build minimal hand-rolled fixtures for the
# subtypes the shipped annotated.pdf doesn't carry (FreeText with /DA,
# /Popup, /IRT, and FileAttachment with /FS).

# Helper: assemble an in-memory PDF from a list of object bodies.
# `obj_parts` is a list of charToRaw()'d body chunks (one per object).
build_inline_pdf <- function(obj_parts) {
  header <- charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
  parts <- c(list(header), obj_parts)
  cum <- c(0L, cumsum(vapply(parts, length, integer(1L))))
  n_objs <- length(obj_parts)
  offs <- cum[seq_len(n_objs) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  xref <- paste(
    c("xref",
      paste0("0 ", n_objs + 1L),
      "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size ", n_objs + 1L,
    " /Root 1 0 R >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  c(unlist(parts), charToRaw(xref), charToRaw(trailer))
}

# Helper: format a single PDF object as bytes.
inline_obj <- function(n, body) {
  charToRaw(paste0(n, " 0 obj\n", body, "\nendobj\n"))
}

# Inline PDF carrying a Square annot with an explicit /Border so
# FPDFAnnot_GetBorder returns TRUE and cpp_annot_border returns the
# width.
build_bordered_pdf <- function() {
  build_inline_pdf(list(
    inline_obj(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    inline_obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    inline_obj(3, paste0(
      "<< /Type /Page /Parent 2 0 R ",
      "/MediaBox [0 0 300 300] /Resources <<>> ",
      "/Annots [4 0 R] >>")),
    inline_obj(4, paste0(
      "<< /Type /Annot /Subtype /Square ",
      "/Rect [10 10 100 100] /Border [0 0 3] >>"))
  ))
}

# Inline PDF carrying an Ink annot with two strokes: one empty
# (zero points) and one with two points. Exercises the empty-stroke
# branch of cpp_annot_ink_paths_handle.
build_ink_empty_stroke_pdf <- function() {
  build_inline_pdf(list(
    inline_obj(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    inline_obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    inline_obj(3, paste0(
      "<< /Type /Page /Parent 2 0 R ",
      "/MediaBox [0 0 300 300] /Resources <<>> ",
      "/Annots [4 0 R] >>")),
    inline_obj(4, paste0(
      "<< /Type /Annot /Subtype /Ink ",
      "/Rect [10 10 200 200] ",
      "/InkList [ [] [10 10 50 50] ] >>"))
  ))
}

# Inline PDF carrying a /Popup link (text -> popup) and an /IRT link
# (text -> earlier text) so we can exercise both branches of
# cpp_annot_linked_handle's success path on the same doc.
build_linked_pdf <- function() {
  build_inline_pdf(list(
    inline_obj(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    inline_obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    inline_obj(3, paste0(
      "<< /Type /Page /Parent 2 0 R ",
      "/MediaBox [0 0 300 300] /Resources <<>> ",
      "/Annots [4 0 R 5 0 R 6 0 R] >>")),
    # Text annot pointing /Popup -> 5 0 R
    inline_obj(4, paste0(
      "<< /Type /Annot /Subtype /Text /Rect [20 250 40 270] ",
      "/Contents (Question) /T (Alice) /Popup 5 0 R >>")),
    # Popup annot
    inline_obj(5, paste0(
      "<< /Type /Annot /Subtype /Popup ",
      "/Rect [50 250 250 280] /Parent 4 0 R >>")),
    # Text annot with /IRT pointing back to 4 0 R
    inline_obj(6, paste0(
      "<< /Type /Annot /Subtype /Text /Rect [20 200 40 220] ",
      "/Contents (Reply) /T (Bob) /IRT 4 0 R >>"))
  ))
}

# Inline PDF carrying a FreeText annot with /DA setting the text
# colour to red (1 0 0 rg) — enough for FPDFAnnot_GetFontColor to
# return a non-zero RGB triple via the form-fill env.
build_freetext_pdf <- function() {
  build_inline_pdf(list(
    inline_obj(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    inline_obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    inline_obj(3, paste0(
      "<< /Type /Page /Parent 2 0 R ",
      "/MediaBox [0 0 300 300] /Resources <<>> ",
      "/Annots [4 0 R] >>")),
    inline_obj(4, paste0(
      "<< /Type /Annot /Subtype /FreeText ",
      "/Rect [10 10 200 50] /Contents (Test) ",
      "/DA (/Helv 12 Tf 1 0 0 rg) >>"))
  ))
}

# Inline PDF carrying a FileAttachment annot whose /FS points at a
# filespec dict, which in turn embeds a small text/plain stream.
build_file_attachment_annot_pdf <- function() {
  embed_bytes <- charToRaw("Sample data\n")
  obj6_head <- charToRaw(paste0(
    "6 0 obj\n<< /Type /EmbeddedFile /Subtype /text#2Fplain ",
    "/Length ", length(embed_bytes), " >>\nstream\n"))
  obj6 <- c(obj6_head, embed_bytes, charToRaw("\nendstream\nendobj\n"))
  build_inline_pdf(list(
    inline_obj(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    inline_obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    inline_obj(3, paste0(
      "<< /Type /Page /Parent 2 0 R ",
      "/MediaBox [0 0 300 300] /Resources <<>> ",
      "/Annots [4 0 R] >>")),
    inline_obj(4, paste0(
      "<< /Type /Annot /Subtype /FileAttachment ",
      "/Rect [10 10 30 30] /Contents (See attachment) ",
      "/FS 5 0 R >>")),
    inline_obj(5, paste0(
      "<< /Type /Filespec /F (data.txt) /UF (data.txt) ",
      "/EF << /F 6 0 R >> >>")),
    obj6
  ))
}

# cpp_annot_get out-of-range path ----------------------------------

test_that("cpp_annot_get errors when the index exceeds the page's annots", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  # annotated.pdf has 5 annots; asking for index 99 makes
  # FPDFPage_GetAnnot return NULL and triggers the Rcpp::stop.
  expect_error(
    pdfium:::cpp_annot_get(page$ptr, doc$ptr, 99L),
    "FPDFPage_GetAnnot\\(99\\) returned NULL"
  )
})

# cpp_annot_delete not-on-page path --------------------------------

test_that("cpp_annot_delete returns FALSE for an annotation on another page", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page1 <- pdf_page_new(doc, page_num = 1L, width = 300, height = 300)
  on.exit(pdf_page_close(page1), add = TRUE, after = FALSE)
  page2 <- pdf_page_new(doc, page_num = 2L, width = 300, height = 300)
  on.exit(pdf_page_close(page2), add = TRUE, after = FALSE)
  a <- pdf_annot_new(page1, "square", bounds = c(10, 10, 50, 50))
  pdf_annot_new(page2, "circle", bounds = c(10, 10, 50, 50))
  # FPDFPage_GetAnnotIndex finds no match on page 2, so neither page
  # loses an annotation and the handle stays open.
  expect_false(pdfium:::cpp_annot_delete(page2$ptr, a$ptr))
  expect_true(is_open(a))
  expect_identical(
    vapply(pdf_annotations(page1), pdf_annot_subtype, character(1L)),
    "square"
  )
  expect_identical(
    vapply(pdf_annotations(page2), pdf_annot_subtype, character(1L)),
    "circle"
  )
})

# cpp_annot_border NA branch ---------------------------------------

test_that("pdf_annot_border_width is NA for annots with no /Border", {
  doc <- pdf_doc_open(fixture_path("annot_geom"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  # The polygon, ink, and highlight in annot_geom.pdf carry no
  # /Border or /BS entry; FPDFAnnot_GetBorder returns FALSE and the
  # wrapper hands back NA_REAL.
  for (a in annots) {
    expect_true(is.na(pdf_annot_border_width(a)))
  }
})

# cpp_annot_border success branch ----------------------------------

test_that("pdf_annot_border_width returns the /Border width", {
  bytes <- build_bordered_pdf()
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  a <- annots[[1L]]
  expect_identical(pdf_annot_subtype(a), "square")
  # /Border = [hradius vradius width] = [0 0 3]; width is the third.
  expect_equal(pdf_annot_border_width(a), 3)
})

# cpp_annot_has_attachment_points ----------------------------------

test_that("cpp_annot_has_attachment_points exposes both branches", {
  doc <- pdf_doc_open(fixture_path("annot_geom"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  types <- vapply(annots, pdf_annot_subtype, character(1L))
  # Highlight (subtype 9) carries /QuadPoints — TRUE branch.
  hl <- annots[types == "highlight"][[1L]]
  expect_true(pdfium:::cpp_annot_has_attachment_points(hl$ptr))
  # Polygon / ink (no quad points) — FALSE branch.
  poly <- annots[types == "polygon"][[1L]]
  expect_false(pdfium:::cpp_annot_has_attachment_points(poly$ptr))
  ink <- annots[types == "ink"][[1L]]
  expect_false(pdfium:::cpp_annot_has_attachment_points(ink$ptr))
})

# cpp_annot_vertices_handle success branch -------------------------

test_that("pdf_annot_vertices returns the polygon's /Vertices matrix", {
  doc <- pdf_doc_open(fixture_path("annot_geom"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  types <- vapply(annots, pdf_annot_subtype, character(1L))
  poly <- annots[types == "polygon"][[1L]]
  v <- pdf_annot_vertices(poly)
  expect_true(is.matrix(v))
  expect_equal(dim(v), c(3L, 2L))
  expect_identical(colnames(v), c("x", "y"))
  # Triangle vertices from the fixture (see build_annot_geom in
  # tools/build-fixtures.R).
  expect_equal(unname(v[1L, ]), c(10, 10))
  expect_equal(unname(v[2L, ]), c(60, 10))
  expect_equal(unname(v[3L, ]), c(35, 60))
})

# cpp_annot_ink_paths_handle empty-stroke branch -------------------

test_that("pdf_annot_ink_paths returns a 0x2 matrix for an empty stroke", {
  bytes <- build_ink_empty_stroke_pdf()
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  a <- annots[[1L]]
  expect_identical(pdf_annot_subtype(a), "ink")
  paths <- pdf_annot_ink_paths(a)
  expect_length(paths, 2L)
  # First stroke has zero points — empty 0x2 matrix; the second has
  # two points.
  expect_equal(dim(paths[[1L]]), c(0L, 2L))
  expect_equal(dim(paths[[2L]]), c(2L, 2L))
})

# cpp_annot_ink_paths_handle success branch ------------------------

test_that("pdf_annot_ink_paths returns the ink annot's /InkList", {
  doc <- pdf_doc_open(fixture_path("annot_geom"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  types <- vapply(annots, pdf_annot_subtype, character(1L))
  ink <- annots[types == "ink"][[1L]]
  paths <- pdf_annot_ink_paths(ink)
  expect_type(paths, "list")
  expect_length(paths, 2L)
  # Two strokes: 3-point and 2-point.
  expect_equal(dim(paths[[1L]]), c(3L, 2L))
  expect_equal(dim(paths[[2L]]), c(2L, 2L))
  expect_identical(colnames(paths[[1L]]), c("x", "y"))
  expect_equal(unname(paths[[1L]][1L, ]), c(100, 100))
  expect_equal(unname(paths[[2L]][1L, ]), c(120, 180))
})

# cpp_annot_quad_points_handle success branch ----------------------

test_that("pdf_annot_quad_points returns the highlight's /QuadPoints", {
  doc <- pdf_doc_open(fixture_path("annot_geom"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  types <- vapply(annots, pdf_annot_subtype, character(1L))
  hl <- annots[types == "highlight"][[1L]]
  q <- pdf_annot_quad_points(hl)
  expect_true(is.matrix(q))
  expect_equal(dim(q), c(2L, 8L))
  # First row matches the first quad set in build_annot_geom.
  expect_equal(unname(q[1L, ]),
               c(50, 290, 250, 290, 50, 270, 250, 270))
})

# cpp_annot_font_color success branch ------------------------------

test_that("pdf_annot_font_color returns the FreeText annot's /DA colour", {
  bytes <- build_freetext_pdf()
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  expect_length(annots, 1L)
  a <- annots[[1L]]
  expect_identical(pdf_annot_subtype(a), "freetext")
  fc <- pdf_annot_font_color(a)
  expect_named(fc, c("red", "green", "blue"))
  # /DA contains "1 0 0 rg" — pure red.
  expect_equal(fc[["red"]],   1)
  expect_equal(fc[["green"]], 0)
  expect_equal(fc[["blue"]],  0)
})

# cpp_annot_linked_handle Popup + IRT success branches -------------

test_that("pdf_annot_popup resolves a /Popup link to a fresh handle", {
  bytes <- build_linked_pdf()
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  a1 <- annots[[1L]]
  popup <- pdf_annot_popup(a1)
  expect_s3_class(popup, "pdfium_annot")
  expect_identical(popup$index, 2L)
  expect_identical(pdf_annot_subtype(popup), "popup")
})

test_that("pdf_annot_in_reply_to resolves an /IRT link to a fresh handle", {
  bytes <- build_linked_pdf()
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  reply <- annots[[3L]]
  parent <- pdf_annot_in_reply_to(reply)
  expect_s3_class(parent, "pdfium_annot")
  expect_identical(parent$index, 1L)
  expect_identical(pdf_annot_subtype(parent), "text")
})

# cpp_annot_file_attachment_name_handle success branch -------------

test_that("pdf_annot_file_attachment_name returns the embedded filename", {
  bytes <- build_file_attachment_annot_pdf()
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)
  annots <- pdf_annotations(doc, page_num = 1L)
  a <- annots[[1L]]
  expect_identical(pdf_annot_subtype(a), "fileattachment")
  expect_identical(pdf_annot_file_attachment_name(a), "data.txt")
})

test_that("pdf_annot_file_attachment_name is empty when /FS is missing", {
  # A fileattachment annot freshly created by pdf_annot_new() has no
  # /FS dictionary and thus no FPDF_ATTACHMENT — the function returns
  # "" via the att == nullptr early branch.
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  a <- pdf_annot_new(page, "fileattachment", bounds = c(10, 10, 30, 30))
  expect_identical(pdf_annot_file_attachment_name(a), "")
})

# pdf_doc_close() and live annotation handles (ADR-024) ------------
#
# An annotation handle owns a PDFium annotation context, released
# together with the page-objects of its appearance stream. Closing a
# document closes every annotation handle still open on it first, so
# no context outlives its document.

test_that("pdf_doc_close() closes annotation handles from every source", {
  doc <- pdf_doc_open(fixture_path("annotated"), readwrite = TRUE)
  page <- pdf_page_load(doc, 1L)
  linked_doc <- pdf_doc_open(source = build_linked_pdf())
  linked <- pdf_annotations(linked_doc, page_num = 1L)
  handles <- list(
    list_item = pdf_annotations(page)[[1L]],
    at = pdf_annot_at(page, 2L),
    link_hit = pdf_link_annot_at_point(page, 125, 160),
    new = pdf_annot_new(page, "square", bounds = c(10, 10, 50, 50)),
    form_field = pdf_form_fields(doc)[[1L]],
    popup = pdf_annot_popup(linked[[1L]]),
    in_reply_to = pdf_annot_in_reply_to(linked[[3L]])
  )
  for (nm in names(handles)) {
    expect_true(is_open(handles[[nm]]), info = nm)
  }
  pdf_doc_close(doc)
  pdf_doc_close(linked_doc)
  for (nm in names(handles)) {
    expect_false(is_open(handles[[nm]]), info = nm)
    expect_false(pdfium:::cpp_handle_is_valid(handles[[nm]]$ptr), info = nm)
    expect_error(
      pdf_annot_subtype(handles[[nm]]),
      "Annotation handle has been closed",
      info = nm
    )
  }
  expect_identical(vapply(linked, is_open, logical(1L)), rep(FALSE, 3L))
  rm(handles, linked)
  expect_no_error(gc())
})

test_that("annotation handles bound across page and document close", {
  doc <- pdf_doc_new()
  page <- pdf_page_new(doc, page_num = 1L, width = 300, height = 300)
  stamp <- pdf_annot_new(page, "stamp", bounds = c(0, 0, 200, 200))
  pdf_annot_append_object(stamp, pdf_text_new(page, "Hello", x = 10, y = 10))
  pdf_annot_append_object(stamp, pdf_rect_new(page, 20, 20, 50, 50))
  expect_identical(pdf_annot_object_count(stamp), 2L)
  # A second handle to the same annotation has a context of its own.
  again <- pdf_annotations(page)[[1L]]
  pdf_page_close(page)
  # A closed page leaves each context with its handle until the
  # handle is collected or the document closes.
  expect_true(pdfium:::cpp_handle_is_valid(stamp$ptr))
  expect_true(pdfium:::cpp_handle_is_valid(again$ptr))
  pdf_doc_close(doc)
  expect_false(pdfium:::cpp_handle_is_valid(stamp$ptr))
  expect_false(pdfium:::cpp_handle_is_valid(again$ptr))
  expect_no_error(gc())
  rm(stamp, again)
  expect_no_error(gc())
})

test_that("pdf_doc_close() leaves other documents' annotation handles open", {
  doc_a <- pdf_doc_open(fixture_path("annotated"))
  page_a <- pdf_page_load(doc_a, 1L)
  doc_b <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc_b), add = TRUE)
  page_b <- pdf_page_load(doc_b, 1L)
  on.exit(pdf_page_close(page_b), add = TRUE, after = FALSE)
  # Collected handles leave the registry, so doc_b's handles below may
  # reuse their memory without closing doc_a reaching them.
  for (i in seq_len(20L)) pdf_annotations(page_a)
  gc()
  kept_a <- pdf_annotations(page_a)
  handles_b <- pdf_annotations(page_b)
  pdf_page_close(page_a)
  pdf_doc_close(doc_a)
  expect_identical(
    vapply(
      kept_a, function(h) pdfium:::cpp_handle_is_valid(h$ptr),
      logical(1L)
    ),
    rep(FALSE, 5L)
  )
  expect_identical(vapply(handles_b, is_open, logical(1L)), rep(TRUE, 5L))
  expect_identical(
    vapply(handles_b, pdf_annot_subtype, character(1L)),
    c("text", "highlight", "link", "widget", "widget")
  )
})

test_that("cpp_annot_get refuses a closed document handle", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  closed <- pdf_doc_open(fixture_path("minimal"))
  pdf_doc_close(closed)
  expect_error(
    pdfium:::cpp_annot_get(page$ptr, closed$ptr, 0L),
    "Document handle is NULL"
  )
})
