# Tests for pdf_doc_summary() — the one-call "everything about this
# PDF" helper introduced post-v0.1.0. Exercises each column it
# claims to produce against the shipped fixtures.

test_that("pdf_doc_summary returns a one-row tibble", {
  s <- pdf_doc_summary(fixture_path("shapes"))
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 1L)
})

test_that("pdf_doc_summary covers every documented column", {
  s <- pdf_doc_summary(fixture_path("shapes"))
  expected <- c(
    "path", "page_count", "file_version",
    "title", "author", "subject", "keywords",
    "creator", "producer", "creation_date", "mod_date", "trapped",
    "creation_date_parsed", "mod_date_parsed",
    "is_tagged", "is_encrypted", "security_revision", "xref_valid",
    "bookmark_count", "attachment_count", "signature_count",
    "form_field_count", "javascript_count", "named_dest_count",
    "has_page_labels", "file_id_permanent", "file_id_changing"
  )
  expect_named(s, expected)
})

test_that("pdf_doc_summary column types are stable", {
  s <- pdf_doc_summary(fixture_path("shapes"))
  expect_type(s$path, "character")
  expect_type(s$page_count, "integer")
  expect_type(s$file_version, "integer")
  expect_type(s$title, "character")
  expect_s3_class(s$creation_date_parsed, "POSIXct")
  expect_type(s$is_tagged, "logical")
  expect_type(s$is_encrypted, "logical")
  expect_type(s$xref_valid, "logical")
  expect_type(s$bookmark_count, "integer")
  expect_type(s$attachment_count, "integer")
  expect_type(s$signature_count, "integer")
  expect_type(s$form_field_count, "integer")
  expect_type(s$javascript_count, "integer")
  expect_type(s$named_dest_count, "integer")
  expect_type(s$has_page_labels, "logical")
})

test_that("pdf_doc_summary reports counts on the annotated fixture", {
  s <- pdf_doc_summary(fixture_path("annotated"))
  # annotated.pdf has form fields + annotations.
  expect_gt(s$form_field_count, 0L)
  expect_identical(s$page_count, 1L)
})

test_that("pdf_doc_summary reports attachment count on attachments fixture", {
  s <- pdf_doc_summary(fixture_path("attachments"))
  expect_identical(s$attachment_count, 1L)
})

test_that("pdf_doc_summary reports zero counts on simple fixtures", {
  s <- pdf_doc_summary(fixture_path("shapes"))
  # shapes.pdf is a hand-built fixture that has no attachments,
  # signatures, or form fields.
  expect_identical(s$attachment_count, 0L)
  expect_identical(s$signature_count, 0L)
  expect_identical(s$form_field_count, 0L)
  # Counts that are >= 0 integer scalars; exact values depend on
  # the fixture build and aren't relevant to the contract.
  expect_true(s$javascript_count >= 0L)
  expect_true(s$bookmark_count >= 0L)
  expect_true(s$named_dest_count >= 0L)
})

test_that("pdf_doc_summary accepts a path or an open doc", {
  by_path <- pdf_doc_summary(fixture_path("shapes"))
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_doc_summary(doc)
  # `path` differs (one is the doc's `path` slot, the other came in
  # via path resolution); drop it before comparing.
  drop_path <- function(t) t[, names(t) != "path"]
  expect_identical(drop_path(by_path), drop_path(by_doc))
})

test_that("pdf_doc_summary forwards the password argument", {
  # When `doc` is already open, password is ignored. Exercise the
  # path branch where it's forwarded to pdf_doc_open(). Use NULL to
  # confirm the no-password path doesn't trip the assertion.
  s <- pdf_doc_summary(fixture_path("shapes"), password = NULL)
  expect_equal(nrow(s), 1L)
})

test_that("pdf_doc_summary rejects a closed doc", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_summary(doc), "Document has been closed")
})

test_that("pdf_doc_summary rejects bad input", {
  expect_error(pdf_doc_summary(42L), "Assertion on")
  expect_error(pdf_doc_summary(NULL), "Assertion on")
})

test_that("pdf_doc_summary's is_encrypted is FALSE on unencrypted PDFs", {
  s <- pdf_doc_summary(fixture_path("shapes"))
  expect_false(s$is_encrypted)
  expect_true(is.na(s$security_revision))
})

test_that("pdf_doc_summary's path slot reflects the source", {
  s_path <- pdf_doc_summary(fixture_path("shapes"))
  expect_match(s_path$path, "shapes\\.pdf$")

  bytes <- readBin(fixture_path("shapes"), "raw",
                   file.info(fixture_path("shapes"))$size)
  doc_raw <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc_raw), add = TRUE)
  s_raw <- pdf_doc_summary(doc_raw)
  expect_identical(s_raw$path, "<raw bytes>")
})

# file_id_hex_or_na ------------------------------------------------
# The hex-string branch isn't exercised through pdf_doc_summary
# itself because no shipped fixture sets the /ID trailer entry.
# Test the helper directly.

test_that("file_id_hex_or_na returns NA on empty raw", {
  expect_identical(pdfium:::file_id_hex_or_na(raw(0)), NA_character_)
})

test_that("file_id_hex_or_na hex-encodes non-empty raw bytes", {
  bytes <- as.raw(c(0x00, 0xff, 0xab, 0x10))
  expect_identical(pdfium:::file_id_hex_or_na(bytes), "00ffab10")
})
