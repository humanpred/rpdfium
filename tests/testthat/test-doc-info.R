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

test_that("pdf_doc_meta round-trips non-ASCII characters via UTF-16LE", {
  # Exercise pdfium_r::utf16le_to_utf8 (utf16.h) for the 2-byte
  # (Latin supplement), 3-byte (CJK), and 4-byte (supplementary
  # plane / emoji, surrogate-pair branch lines 24-29 + 42-45)
  # UTF-8 emit paths. The /Info dict in a PDF is a natural place
  # to round-trip arbitrary Unicode because PDFium emits it via
  # FPDF_GetMetaText -> UTF-16LE -> our decoder.
  bytes <- charToRaw(paste0(
    "%PDF-1.4\n",
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
    "2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj\n",
    "3 0 obj << /Type /Page /Parent 2 0 R /Resources << >>\n",
    "  /MediaBox [0 0 100 100] >> endobj\n"
  ))
  # Build an Info dict whose Title is a UTF-16BE-encoded
  # string carrying "é中\U0001F600" (Latin-1 supplement + CJK +
  # supplementary-plane emoji requiring a surrogate pair).
  # PDF spec: text strings are detected as UTF-16BE if they
  # start with the BOM (0xFE 0xFF).
  bom <- as.raw(c(0xFE, 0xFF))
  # UTF-16BE bytes for U+00E9 (é), U+4E2D (中), U+1F600 (surrogate
  # pair: D83D DE00).
  u16be <- as.raw(c(
    0x00, 0xE9,            # é
    0x4E, 0x2D,            # 中
    0xD8, 0x3D, 0xDE, 0x00 # 😀
  ))
  # Escape "(" and ")" in PDF literal strings; none of these bytes
  # collide, so we can write them as a literal string between
  # parentheses.
  title_bytes <- c(charToRaw("("), bom, u16be, charToRaw(")"))
  info_head <- charToRaw("4 0 obj << /Title ")
  info_tail <- charToRaw(" >> endobj\n")
  info_obj <- c(info_head, title_bytes, info_tail)

  obj1_off <- 9L  # after "%PDF-1.4\n"
  obj2_off <- obj1_off + nchar("1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n")
  obj3_off <- obj2_off + nchar("2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj\n")
  obj4_off <- length(bytes)
  xref_off <- obj4_off + length(info_obj)
  xref_lines <- c(
    "xref\n0 5\n",
    "0000000000 65535 f \n",
    sprintf("%010d 00000 n \n", obj1_off),
    sprintf("%010d 00000 n \n", obj2_off),
    sprintf("%010d 00000 n \n", obj3_off),
    sprintf("%010d 00000 n \n", obj4_off)
  )
  xref_bytes <- charToRaw(paste(xref_lines, collapse = ""))
  trailer_bytes <- charToRaw(sprintf(
    "trailer << /Size 5 /Root 1 0 R /Info 4 0 R >>\nstartxref\n%d\n%%%%EOF\n",
    xref_off
  ))
  full <- c(bytes, info_obj, xref_bytes, trailer_bytes)
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)
  doc <- pdf_doc_open(tf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  title <- pdf_doc_meta(doc, "Title")
  expect_identical(title, "é中\U0001F600")
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
