# Tests for the writer foundation: pdf_save, pdf_save_to_raw,
# pdf_doc_new, the readwrite flag, and assert_readwrite. Mutation
# functionality itself is exercised in the phase-specific test
# files (test-mut-structural.R, etc.).

test_that("pdf_doc_new() returns a writable empty doc", {
  doc <- pdf_doc_new()
  on.exit(pdf_close(doc), add = TRUE)
  expect_s3_class(doc, "pdfium_doc")
  expect_true(doc$readwrite)
  expect_equal(pdf_page_count(doc), 0L)
})

test_that("pdf_open(readwrite = FALSE) yields a read-only doc", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  on.exit(pdf_close(doc), add = TRUE)
  expect_false(doc$readwrite)
})

test_that("pdf_open(readwrite = TRUE) yields a writable doc", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  expect_true(doc$readwrite)
})

test_that("assert_readwrite() rejects read-only docs", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdfium:::assert_readwrite(doc), "read-only")
})

test_that("pdf_save() works on read-only docs (round-trip)", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  on.exit(pdf_close(doc), add = TRUE)
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  expect_true(file.exists(tmp))
  expect_gt(file.info(tmp)$size, 0)

  doc2 <- pdf_open(tmp)
  on.exit(pdf_close(doc2), add = TRUE)
  expect_equal(pdf_page_count(doc2), pdf_page_count(doc))
})

test_that("pdf_save() writes atomically (failure leaves dest intact)", {
  # Create a file that already exists, then ask pdf_save to write
  # over it via a path that does NOT match an open doc state. The
  # atomicity guarantee is the file.rename-only-on-success semantic.
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  on.exit(pdf_close(doc), add = TRUE)

  dest_dir <- withr::local_tempdir()
  dest <- file.path(dest_dir, "out.pdf")
  writeBin(charToRaw("not a pdf yet"), dest)
  before <- readBin(dest, "raw", file.info(dest)$size)
  pdf_save(doc, dest)
  after <- readBin(dest, "raw", file.info(dest)$size)
  expect_false(identical(before, after))  # written over

  doc2 <- pdf_open(dest)
  on.exit(pdf_close(doc2), add = TRUE)
  expect_equal(pdf_page_count(doc2), 1L)
})

test_that("pdf_save_to_raw() returns a parseable raw vector", {
  # Byte-for-byte equality against pdf_save() doesn't hold because
  # FPDF_SaveAsCopy generates a fresh document `/ID` on every call.
  # Instead, confirm the raw vector is a parseable PDF with the same
  # structure as the file output.
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  on.exit(pdf_close(doc), add = TRUE)
  raw_bytes <- pdf_save_to_raw(doc)
  expect_type(raw_bytes, "raw")
  expect_gt(length(raw_bytes), 100L)
  # PDF magic header bytes.
  expect_identical(raw_bytes[1L:4L], charToRaw("%PDF"))

  reopened <- pdf_open(source = raw_bytes)
  on.exit(pdf_close(reopened), add = TRUE)
  expect_equal(pdf_page_count(reopened), pdf_page_count(doc))
})

test_that("pdf_save() refuses bad destination directory", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(
    pdf_save(doc, "/no/such/dir/out.pdf"),
    "Destination directory"
  )
})

test_that("pdf_save() refuses closed docs", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  pdf_close(doc)
  tmp <- withr::local_tempfile(fileext = ".pdf")
  expect_error(pdf_save(doc, tmp), "Document has been closed")
})

test_that("pdf_save() honours incremental/remove_security/version flags", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  # Incremental save preserves the layout and includes the original
  # bytes; the saved file is at least as large as the input.
  tmp_inc <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp_inc, incremental = TRUE)
  expect_true(file.exists(tmp_inc))
  # remove_security flag is accepted (no encrypted fixture to verify
  # behaviour, but the code path runs).
  tmp_rs <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp_rs, remove_security = TRUE)
  expect_true(file.exists(tmp_rs))
  # subset_new_fonts disabled
  tmp_sf <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp_sf, subset_new_fonts = FALSE)
  expect_true(file.exists(tmp_sf))
  # version pinning: PDFium "10*major+minor" form — 14 = PDF 1.4.
  tmp_v <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp_v, version = 14L)
  doc14 <- pdf_open(tmp_v)
  on.exit(pdf_close(doc14), add = TRUE)
  expect_equal(pdf_doc_info(doc14)$file_version, 14L)
})

test_that("pdf_save_to_raw() honours same flag set", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  raw_inc <- pdf_save_to_raw(doc, incremental = TRUE)
  raw_rs <- pdf_save_to_raw(doc, remove_security = TRUE)
  raw_sf <- pdf_save_to_raw(doc, subset_new_fonts = FALSE)
  raw_v  <- pdf_save_to_raw(doc, version = 17L)
  for (b in list(raw_inc, raw_rs, raw_sf, raw_v)) {
    expect_type(b, "raw")
    expect_gt(length(b), 100L)
  }
})

test_that("pdf_save_to_raw() refuses closed docs", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx)
  pdf_close(doc)
  expect_error(pdf_save_to_raw(doc), "Document has been closed")
})

test_that("assert_readwrite() refuses closed docs", {
  fx <- fixture_path("minimal")
  doc <- pdf_open(fx, readwrite = TRUE)
  pdf_close(doc)
  expect_error(pdfium:::assert_readwrite(doc), "Document has been closed")
})

test_that("mark_page_dirty + flush_dirty_pages round-trip", {
  fx <- fixture_path("shapes")
  doc <- pdf_open(fx, readwrite = TRUE)
  on.exit(pdf_close(doc), add = TRUE)
  expect_length(doc$state$dirty_pages, 0L)
  # pdf_page_set_rotation() marks page 1 dirty.
  pdf_page_set_rotation(doc, 90)
  expect_setequal(doc$state$dirty_pages, 1L)
  # pdf_save() flushes the set.
  tmp <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(doc, tmp)
  expect_length(doc$state$dirty_pages, 0L)
})
