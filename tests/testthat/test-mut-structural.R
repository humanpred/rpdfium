# Tests for Phase 2 structural mutation: page rotation, delete,
# reorder, merge, n-up, new-page, set-box, set-language.
# Function names follow the ADR-018 object-first convention.

test_that("pdf_page_set_rotation() rejects ro docs and bad values", {
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_page_set_rotation(doc, 90), "read-only")

  doc_rw <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc_rw), add = TRUE)
  expect_error(pdf_page_set_rotation(doc_rw, 45),
               "Assertion on")
})

test_that("pdf_page_set_rotation() persists across save (doc input)", {
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_equal(pdf_page_rotation(doc, 1), 0L)
  pdf_page_set_rotation(doc, 270, page_num = 1L)

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  doc2 <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  expect_equal(pdf_page_rotation(doc2, 1), 270L)
})

test_that("pdf_page_set_rotation() accepts a pdfium_page", {
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE)
  pdf_page_set_rotation(page, 180)

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  doc2 <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  expect_equal(pdf_page_rotation(doc2, 1), 180L)
})

test_that("pdf_page_rotation() reads back a 90-deg rotation", {
  # Covers the `case 1: return 90;` branch in cpp_page_rotation
  # (page.cpp). The other rotation cases are exercised by the 180 /
  # 270 set-rotation tests above.
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  pdf_page_set_rotation(doc, 90, page_num = 1L)

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  doc2 <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  expect_equal(pdf_page_rotation(doc2, 1), 90L)
})

test_that("pdf_page_delete() removes the page", {
  fx <- fixture_path("shapes")
  src_doc <- pdf_doc_open(fx)
  src_n <- pdf_page_count(src_doc)
  pdf_doc_close(src_doc)
  if (src_n < 2L) {
    tmp <- withr::local_tempfile(fileext = ".pdf")
    pdf_docs_merge(list(fx, fx), tmp)
    fx_2 <- tmp
  } else {
    fx_2 <- fx
  }
  doc <- pdf_doc_open(fx_2, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  n_before <- pdf_page_count(doc)
  pdf_page_delete(doc, 1)
  expect_equal(pdf_page_count(doc), n_before - 1L)
})

test_that("pdf_page_delete() rejects out-of-range page_num", {
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_page_delete(doc, 999L), "exceeds")
})

test_that("pdf_docs_merge() concatenates pages", {
  fx <- fixture_path("minimal")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_docs_merge(list(fx, fx, fx), tmp)
  doc <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_equal(pdf_page_count(doc), 3L)
})

test_that("pdf_docs_merge() with file = NULL returns an open doc", {
  fx <- fixture_path("minimal")
  out <- pdf_docs_merge(list(fx, fx))
  on.exit(pdf_doc_close(out), add = TRUE)
  expect_s3_class(out, "pdfium_doc")
  expect_equal(pdf_page_count(out), 2L)
  expect_true(out$readwrite)
})

test_that("pdf_n_up() builds an N-up imposition", {
  fx <- fixture_path("minimal")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_n_up(pdf_doc_open(fx), tmp, cols = 2L, rows = 1L)
  doc <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_gte(pdf_page_count(doc), 1L)
})

test_that("cpp_import_n_pages_to_one externalptr GC frees the doc", {
  # pdf_n_up() always close()s the n-up output explicitly so its
  # lambda finalizer hits the "already-cleared" branch. Driving the
  # shim directly and forcing GC exercises the close-on-GC code
  # path in the inline lambda (mutation.cpp lines 130-131).
  src <- pdf_doc_open(fixture_path("minimal"))
  on.exit(pdf_doc_close(src), add = TRUE)
  local({
    ptr <- pdfium:::cpp_import_n_pages_to_one(src$ptr, 612, 792, 1L, 1L)
    # Verify the externalptr is live before drop.
    expect_true(pdfium:::cpp_handle_is_valid(ptr))
    rm(ptr)
  })
  invisible(gc(verbose = FALSE))
  succeed()
})

test_that("pdf_page_new() inserts at the requested index", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  pdf_page_new(doc, 1, 612, 792)
  pdf_page_new(doc, 2, 595, 842) # A4 second
  expect_equal(pdf_page_count(doc), 2L)
  sz1 <- pdf_page_size(doc, 1)
  sz2 <- pdf_page_size(doc, 2)
  expect_equal(sz1[["width"]], 612)
  expect_equal(sz2[["width"]], 595)
})

test_that("pdf_page_set_box() persists across save", {
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  pdf_page_set_box(doc, "crop", c(10, 20, 200, 300))

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  doc2 <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  bx <- pdf_page_box(doc2, 1, box = "crop")
  expect_equal(unname(bx), c(10, 20, 200, 300))
})

test_that("cpp_page_set_box rejects an unknown box name", {
  # match.arg() in the R wrapper prevents this branch; drive the
  # shim directly so the trailing else stop() is covered.
  doc <- pdf_doc_open(fixture_path("shapes"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  expect_error(
    pdfium:::cpp_page_set_box(page$ptr, "made-up", 0, 0, 10, 10),
    "Unknown box"
  )
})

test_that("pdf_page_set_box() exercises every box variant", {
  # Drive the bleed/trim/art branches in cpp_page_set_box. PDFium
  # writes the dictionary entry on FPDFPage_SetXBox(), and pdf_save
  # serialises that out. The media branch is hit by simply selecting
  # it; even pages that already carry a MediaBox get the value
  # overwritten.
  fx <- fixture_path("shapes")
  rect <- c(5, 10, 100, 150)
  for (box in c("media", "bleed", "trim", "art")) {
    doc <- pdf_doc_open(fx, readwrite = TRUE)
    pdf_page_set_box(doc, box, rect)
    tmp <- withr::local_tempfile(fileext = ".pdf")
    pdf_save(doc, tmp)
    pdf_doc_close(doc)
    doc2 <- pdf_doc_open(tmp)
    bx <- pdf_page_box(doc2, 1, box = box)
    expect_equal(unname(bx), rect, info = box)
    pdf_doc_close(doc2)
  }
})

test_that("pdf_doc_set_language() persists across save", {
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  pdf_doc_set_language(doc, "fr-CA")

  # The reader half (FPDFCatalog_GetLanguage) sees the in-memory catalog
  # immediately, before any save.
  expect_identical(pdf_doc_language(doc), "fr-CA")

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  expect_true(file.exists(tmp))  # smoke (first layer)

  # Pin persistence on the saved bytes too. PDFium writes an all-ASCII
  # tag as a plain PDF literal string; grepRaw(fixed = TRUE) on the raw
  # vector is a binary-safe, locale-independent byte match.
  raw <- readBin(tmp, "raw", file.info(tmp)$size)
  expect_equal(
    length(grepRaw(charToRaw("/Lang(fr-CA)"), raw, fixed = TRUE, all = TRUE)),
    1L
  )

  # Reopen and read back through the public reader to close the loop.
  doc2 <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  expect_identical(pdf_doc_language(doc2), "fr-CA")
})

test_that("pdf_doc_language() returns '' when no /Lang is declared", {
  expect_identical(pdf_doc_language(pdf_doc_open(fixture_path("minimal"))), "")
})

test_that("pdf_doc_set_language() round-trips a non-ASCII tag via UTF-16", {
  # FPDFCatalog_SetLanguage takes an FPDF_WIDESTRING as of chromium/7857;
  # cpp_catalog_set_language() transcodes the UTF-8 input to UTF-16LE. This
  # tag carries a 2-byte (U+00E9) and a 3-byte (U+4E2D) UTF-8 sequence to
  # exercise the multibyte branches of that transcode — it is an encoding
  # path probe, not a realistic BCP-47 tag. PDFium re-serialises a string
  # outside PDFDocEncoding as UTF-16BE with a BOM, so the saved /Lang reads
  # (FE FF 00 E9 4E 2D); a regression in the transcode would scramble it.
  fx <- fixture_path("shapes")
  doc <- pdf_doc_open(fx, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  # Built from code points (pure-ASCII source) so the input is identical
  # regardless of the worker's locale or source-file encoding.
  pdf_doc_set_language(doc, intToUtf8(c(0x00E9L, 0x4E2DL)))

  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  expect_true(file.exists(tmp))  # smoke (first layer)

  raw <- readBin(tmp, "raw", file.info(tmp)$size)
  expected <- c(
    charToRaw("/Lang("),
    as.raw(c(0xFE, 0xFF)),  # UTF-16BE byte-order mark
    as.raw(c(0x00, 0xE9)),  # U+00E9 from 2-byte UTF-8 input
    as.raw(c(0x4E, 0x2D)),  # U+4E2D from 3-byte UTF-8 input
    charToRaw(")")
  )
  expect_equal(length(grepRaw(expected, raw, fixed = TRUE, all = TRUE)), 1L)
})

test_that("pdf_pages_reorder() accepts a full permutation", {
  fx <- fixture_path("minimal")
  src <- withr::local_tempfile(fileext = ".pdf")
  pdf_docs_merge(list(fx, fx, fx), src)
  doc <- pdf_doc_open(src, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  pdf_pages_reorder(doc, new_order = c(3L, 1L, 2L))
  # No regression visible at the page-count level — just exercise the
  # cpp_move_pages branch successfully.
  expect_equal(pdf_page_count(doc), 3L)
  out <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, out)
  doc2 <- pdf_doc_open(out)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  expect_equal(pdf_page_count(doc2), 3L)
})

test_that("pdf_pages_reorder() accepts contiguous-move shape", {
  fx <- fixture_path("minimal")
  src <- withr::local_tempfile(fileext = ".pdf")
  pdf_docs_merge(list(fx, fx, fx), src)
  doc <- pdf_doc_open(src, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  pdf_pages_reorder(doc, move_pages = c(1L, 2L), dest = 2L)
  expect_equal(pdf_page_count(doc), 3L)
})

test_that("pdf_docs_merge() accepts open pdfium_doc handles", {
  fx <- fixture_path("minimal")
  d1 <- pdf_doc_open(fx)
  d2 <- pdf_doc_open(fx)
  on.exit(pdf_doc_close(d1), add = TRUE)
  on.exit(pdf_doc_close(d2), add = TRUE)
  out <- pdf_docs_merge(list(d1, d2))
  on.exit(pdf_doc_close(out), add = TRUE)
  expect_equal(pdf_page_count(out), 2L)
  expect_true(out$readwrite)
})

test_that("pdf_pages_reorder() rejects bad permutations", {
  fx <- fixture_path("minimal")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_docs_merge(list(fx, fx, fx), tmp)
  doc <- pdf_doc_open(tmp, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(
    pdf_pages_reorder(doc, new_order = c(1L, 2L)),  # too short
    "Assertion on"
  )
  expect_error(
    pdf_pages_reorder(doc, new_order = c(1L, 1L, 2L)),  # duplicate
    "Assertion on"
  )
})
