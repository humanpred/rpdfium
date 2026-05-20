# Tests for pdf_doc_info / pdf_doc_meta / pdf_parse_date.

test_that("pdf_doc_info returns the documented list shape", {
  info <- pdf_doc_info(fixture_path("shapes"))
  expect_named(
    info,
    c(
      "page_count", "file_version",
      "title", "author", "subject", "keywords",
      "creator", "producer", "creation_date", "mod_date",
      "trapped",
      "creation_date_parsed", "mod_date_parsed"
    )
  )
  expect_type(info$page_count, "integer")
  expect_type(info$file_version, "integer")
  expect_s3_class(info$creation_date_parsed, "POSIXct")
  expect_s3_class(info$mod_date_parsed, "POSIXct")
})

test_that("pdf_doc_info reports correct page count and a sane PDF version", {
  info <- pdf_doc_info(fixture_path("shapes"))
  expect_equal(info$page_count, 1L)
  # PDFium reports 10*major + minor. PDF 1.x is the only family in
  # wide circulation; PDF 2.0 would report 20. Cairo currently emits
  # PDF 1.5 / 1.6 / 1.7 depending on the feature set used.
  expect_true(info$file_version >= 13L && info$file_version <= 20L)
})

test_that("pdf_doc_info exposes Cairo's Producer string", {
  info <- pdf_doc_info(fixture_path("shapes"))
  expect_match(info$producer, "^cairo ", ignore.case = TRUE)
})

test_that("pdf_doc_info accepts a path or an open doc", {
  by_path <- pdf_doc_info(fixture_path("shapes"))
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_doc_info(doc)
  expect_identical(by_path$producer, by_doc$producer)
  expect_true(is_open(doc)) # not closed by the helper
})

test_that("pdf_doc_info refuses bad inputs and closed docs", {
  expect_error(pdf_doc_info(42), "class .pdfium_doc.")
  expect_error(pdf_doc_info("nope.pdf"), "not found")

  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_info(doc), "Document has been closed")
})

test_that("pdf_doc_meta returns standard tags and validates input", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)

  expect_match(pdf_doc_meta(doc, "Producer"), "^cairo ", ignore.case = TRUE)
  # Absent standard tag returns the empty string.
  expect_identical(pdf_doc_meta(doc, "Title"), "")
  # Custom tag not present -> "".
  expect_identical(pdf_doc_meta(doc, "NotPresent"), "")

  # Input validation.
  expect_error(pdf_doc_meta(doc, ""), "Assertion on")
  expect_error(pdf_doc_meta(doc, NA_character_), "Assertion on")
  expect_error(pdf_doc_meta(doc, 42), "Assertion on")
  expect_error(pdf_doc_meta("notdoc", "Title"), "class .pdfium_doc.")
})

test_that("pdf_doc_meta refuses a closed doc", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(
    pdf_doc_meta(doc, "Producer"),
    "Document has been closed"
  )
})

test_that("pdf_parse_date handles common PDF formats", {
  # Full form with UTC Z suffix.
  expect_equal(
    pdf_parse_date("D:20240115123045Z"),
    as.POSIXct("2024-01-15 12:30:45", tz = "UTC")
  )
  # Without D: prefix.
  expect_equal(
    pdf_parse_date("20240115123045"),
    as.POSIXct("2024-01-15 12:30:45", tz = "UTC")
  )
  # Tz offset (currently ignored - treated as UTC). Document the
  # behavior in case we make it stricter later.
  expect_equal(
    pdf_parse_date("D:20240115123045+05'00'"),
    as.POSIXct("2024-01-15 12:30:45", tz = "UTC")
  )
  # Truncated forms fall back through shorter prefixes.
  expect_equal(
    pdf_parse_date("D:202401"),
    as.POSIXct("2024-01-01 00:00:00", tz = "UTC")
  )
  expect_equal(
    pdf_parse_date("D:2024"),
    as.POSIXct("2024-01-01 00:00:00", tz = "UTC")
  )
})

test_that("pdf_parse_date handles edge cases", {
  # Empty vector.
  expect_length(pdf_parse_date(character(0)), 0L)
  # NA / empty string -> NA.
  expect_true(is.na(pdf_parse_date(NA_character_)))
  expect_true(is.na(pdf_parse_date("")))
  # Junk and too-short digit strings -> NA (a PDF date must include
  # at least a 4-digit year).
  expect_true(is.na(pdf_parse_date("D:")))
  expect_true(is.na(pdf_parse_date("D:abc")))
  expect_true(is.na(pdf_parse_date("D:42")))
  # Vectorized over a length-N input.
  res <- pdf_parse_date(c("D:20240101000000Z", "", "D:20231231235959Z"))
  expect_length(res, 3L)
  expect_true(!is.na(res[1L]))
  expect_true(is.na(res[2L]))
  expect_true(!is.na(res[3L]))
  # Refuses non-character input.
  expect_error(pdf_parse_date(42), "Assertion on")
})

test_that("pdf_doc_info's creation_date round-trips through pdf_parse_date", {
  info <- pdf_doc_info(fixture_path("shapes"))
  expect_match(info$creation_date, "^D:")
  re_parsed <- pdf_parse_date(info$creation_date)
  expect_identical(info$creation_date_parsed, re_parsed)
})
