# Tests for the page-level navigation extras: pdf_link_at_point()
# and pdf_page_actions().

test_that("pdf_link_at_point reports the URI link in annotated.pdf", {
  # annotated.pdf has a link annotation at rect (50, 150)-(200, 170)
  # whose URI action targets https://example.com.
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  out <- pdf_link_at_point(p, x = 125, y = 160)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  expect_equal(out$action_type, "uri")
  expect_equal(out$uri, "https://example.com")
  expect_true(is.na(out$filepath))
  expect_true(is.na(out$dest_page))
  expect_gte(out$z_order, 0L)
  expect_equal(out$left, 50)
  expect_equal(out$bottom, 150)
  expect_equal(out$right, 200)
  expect_equal(out$top, 170)
})

test_that("pdf_link_at_point returns 0 rows when no link is under the point", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)
  out <- pdf_link_at_point(p, x = 10, y = 10)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c(
    "z_order", "left", "bottom", "right", "top",
    "action_type", "uri", "filepath", "dest_page",
    "dest_view", "dest_x", "dest_y", "dest_zoom"
  ))
})

test_that("pdf_link_at_point validates x and y", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  p <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(p), add = TRUE, after = FALSE)

  expect_error(pdf_link_at_point(p, NA_real_, 10), "Assertion on")
  expect_error(pdf_link_at_point(p, 10, c(1, 2)), "Assertion on")
  expect_error(pdf_link_at_point(p, "100", 10), "Assertion on")
  expect_error(pdf_link_at_point(p, 10, Inf), "Assertion on")
})

test_that("pdf_link_at_point accepts a doc + page_num", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_link_at_point(doc, x = 125, y = 160, page_num = 1L)
  expect_equal(nrow(out), 1L)
  expect_equal(out$action_type, "uri")
})

test_that("pdf_page_actions returns empty tibble for typical PDFs", {
  for (name in c("shapes", "outline", "annotated", "minimal")) {
    out <- pdf_page_actions(pdf_doc_open(fixture_path(name)), 1L)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
    expect_named(out, c(
      "trigger", "action_type", "uri", "filepath",
      "dest_page", "dest_view", "dest_x", "dest_y",
      "dest_zoom"
    ))
  }
})

test_that("pdf_page_actions / pdf_link_at_point reject closed pages", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  p <- pdf_page_load(doc, 1L)
  pdf_page_close(p)
  expect_error(pdf_link_at_point(p, 1, 1), "closed")
  expect_error(pdf_page_actions(p), "closed")
  pdf_doc_close(doc)
})

test_that("page-nav functions reject bad page inputs", {
  expect_error(
    pdf_link_at_point("nope", 1, 1),
    "class .pdfium_page./.pdfium_doc."
  )
  expect_error(
    pdf_page_actions(42),
    "class .pdfium_page./.pdfium_doc."
  )
})

# -- /Dest-only link branch in cpp_link_at_point (no /A) ---------------
#
# When a Link annotation has /Dest but no /A action, FPDFLink_GetAction
# returns NULL and cpp_link_at_point falls through to the
# FPDFLink_GetDest fallback path (page_nav.cpp lines 86-96). The
# `action == nullptr` tail then forces action_code = 1 (PDFACTION_GOTO).
test_that("pdf_link_at_point resolves a /Dest-only link to a GoTo", {
  bytes <- charToRaw(paste0(
    "%PDF-1.4\n",
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
    "2 0 obj << /Type /Pages /Count 2 /Kids [3 0 R 4 0 R] >> endobj\n",
    "3 0 obj << /Type /Page /Parent 2 0 R /Resources << >>\n",
    "  /MediaBox [0 0 612 792] /Annots [5 0 R] >> endobj\n",
    "4 0 obj << /Type /Page /Parent 2 0 R /Resources << >>\n",
    "  /MediaBox [0 0 612 792] >> endobj\n",
    # /Link annot with /Dest pointing at page 2 with XYZ view at (100, 200, 0).
    "5 0 obj << /Type /Annot /Subtype /Link /Rect [50 150 200 170]\n",
    "  /Dest [4 0 R /XYZ 100 200 0] >> endobj\n"
  ))
  obj_bodies <- c(
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
    "2 0 obj << /Type /Pages /Count 2 /Kids [3 0 R 4 0 R] >> endobj\n",
    paste0("3 0 obj << /Type /Page /Parent 2 0 R /Resources << >>\n",
           "  /MediaBox [0 0 612 792] /Annots [5 0 R] >> endobj\n"),
    paste0("4 0 obj << /Type /Page /Parent 2 0 R /Resources << >>\n",
           "  /MediaBox [0 0 612 792] >> endobj\n"),
    paste0("5 0 obj << /Type /Annot /Subtype /Link ",
           "/Rect [50 150 200 170]\n",
           "  /Dest [4 0 R /XYZ 100 200 0] >> endobj\n")
  )
  offs <- 9L + c(0L, cumsum(nchar(obj_bodies)))[1:5]
  xref_off <- length(bytes)
  xref <- charToRaw(paste0(
    "xref\n0 6\n0000000000 65535 f \n",
    paste(sprintf("%010d 00000 n ", offs), collapse = "\n"), "\n"
  ))
  trailer <- charToRaw(sprintf(
    "trailer << /Size 6 /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n",
    xref_off
  ))
  full <- c(bytes, xref, trailer)
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  doc <- pdf_doc_open(tf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  out <- pdf_link_at_point(page, x = 125, y = 160)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  # /Dest-only link should classify as GoTo with no /A action.
  expect_identical(out$action_type, "goto")
  expect_identical(out$dest_page, 2L)
  expect_identical(out$dest_view, "xyz")
  expect_equal(out$dest_x, 100)
  expect_equal(out$dest_y, 200)
  # /XYZ destination with zoom = 0 means "preserve current zoom"
  # per PDF spec; PDFium reports that as NA_REAL.
  expect_true(is.na(out$dest_zoom))
})

# -- Page additional-actions branch (/AA on a page object) -----------
#
# A page can carry /AA with /O (Open) and /C (Close) sub-dictionaries,
# each holding an action. cpp_page_aactions iterates both keys and
# pushes one row per defined action; the populated branch (lines
# 141-159 of src/page_nav.cpp) builds the per-action columns.
test_that("pdf_page_actions reports /AA /O and /C JavaScript actions", {
  bytes <- charToRaw(paste0(
    "%PDF-1.4\n",
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
    "2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj\n",
    "3 0 obj << /Type /Page /Parent 2 0 R /Resources << >>\n",
    "  /MediaBox [0 0 612 792]\n",
    "  /AA << /O 4 0 R /C 5 0 R >> >> endobj\n",
    "4 0 obj << /S /JavaScript /JS (open) >> endobj\n",
    "5 0 obj << /S /JavaScript /JS (close) >> endobj\n"
  ))
  obj_bodies <- c(
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
    "2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj\n",
    paste0("3 0 obj << /Type /Page /Parent 2 0 R /Resources << >>\n",
           "  /MediaBox [0 0 612 792]\n",
           "  /AA << /O 4 0 R /C 5 0 R >> >> endobj\n"),
    "4 0 obj << /S /JavaScript /JS (open) >> endobj\n",
    "5 0 obj << /S /JavaScript /JS (close) >> endobj\n"
  )
  offs <- 9L + c(0L, cumsum(nchar(obj_bodies)))[1:5]
  xref_off <- length(bytes)
  xref <- charToRaw(paste0(
    "xref\n0 6\n0000000000 65535 f \n",
    paste(sprintf("%010d 00000 n ", offs), collapse = "\n"), "\n"
  ))
  trailer <- charToRaw(sprintf(
    "trailer << /Size 6 /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n",
    xref_off
  ))
  full <- c(bytes, xref, trailer)
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  doc <- pdf_doc_open(tf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdf_page_actions(doc, page_num = 1L)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 2L)
  expect_identical(out$trigger, c("open", "close"))
  # PDFium classifies /S /JavaScript actions as PDFACTION_UNSUPPORTED
  # (no FPDFAction_GetType code for JS), so action_type is the
  # "unsupported" placeholder. The point is that both rows materialise.
  expect_true(all(out$action_type == "unsupported"))
})
