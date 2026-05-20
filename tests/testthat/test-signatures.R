# Tests for pdf_signatures() / pdf_signature_contents() /
# pdf_signature_byte_range(). signed.pdf is a hand-built fixture
# carrying ONE signature widget annotation whose:
#   /SubFilter is "adbe.pkcs7.detached" (ASCII)
#   /Reason    is "Test" (UTF-16BE BOM + chars)
#   /M (time)  is "D:20260516000000+00'00'"
#   /Contents  is the 4-byte placeholder 0xDEADBEEF
#   /ByteRange is [0 100 200 300] (two pairs)
# It is NOT a cryptographically valid signature; the bytes are a
# placeholder so PDFium has structure to enumerate.

test_that("pdf_signatures returns 0 rows for an unsigned doc", {
  res <- pdf_signatures(fixture_path("shapes"))
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c(
    "signature_index", "sub_filter", "reason",
    "time", "doc_mdp_permission", "contents_size",
    "byte_range_pairs"
  ))
})

test_that("pdf_signatures reports the documented signature", {
  res <- pdf_signatures(fixture_path("signed"))
  expect_equal(nrow(res), 1L)
  expect_identical(res$signature_index, 1L)
  expect_identical(res$sub_filter, "adbe.pkcs7.detached")
  expect_identical(res$reason, "Test")
  expect_identical(res$time, "D:20260516000000+00'00'")
  expect_identical(res$doc_mdp_permission, NA_integer_)
  expect_identical(res$contents_size, 4L)
  expect_identical(res$byte_range_pairs, 2L)
})

test_that("pdf_signature_contents returns the placeholder bytes", {
  raw <- pdf_signature_contents(fixture_path("signed"), 1L)
  expect_type(raw, "raw")
  expect_length(raw, 4L)
  expect_identical(
    as.integer(raw),
    c(0xDEL, 0xADL, 0xBEL, 0xEFL)
  )
})

test_that("pdf_signature_byte_range returns the documented matrix", {
  m <- pdf_signature_byte_range(fixture_path("signed"), 1L)
  expect_true(is.matrix(m))
  expect_equal(dim(m), c(2L, 2L))
  expect_identical(colnames(m), c("offset", "length"))
  expect_identical(m[1L, ], c(offset = 0L, length = 100L))
  expect_identical(m[2L, ], c(offset = 200L, length = 300L))
})

test_that("pdf_signatures accepts a path or an open doc", {
  by_path <- pdf_signatures(fixture_path("signed"))
  doc <- pdf_doc_open(fixture_path("signed"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_signatures(doc)
  expect_identical(by_path, by_doc)
})

test_that("pdf_signature_contents / _byte_range validate their indices", {
  fx <- fixture_path("signed")
  expect_error(pdf_signature_contents(fx, 0), "Assertion on")
  expect_error(pdf_signature_contents(fx, 1.5), "Assertion on")
  expect_error(pdf_signature_contents(fx, NA_integer_), "Assertion on")
  expect_error(pdf_signature_byte_range(fx, 0), "Assertion on")
  expect_error(pdf_signature_byte_range(fx, -1), "Assertion on")
  expect_error(pdf_signature_byte_range(fx, c(1, 2)), "Assertion on")
})

test_that("pdf_signatures rejects bad inputs and closed docs", {
  expect_error(pdf_signatures(42), "class .pdfium_doc.")
  doc <- pdf_doc_open(fixture_path("signed"))
  pdf_doc_close(doc)
  expect_error(pdf_signatures(doc), "Document has been closed")
})

test_that("the time column round-trips through pdf_parse_date", {
  res <- pdf_signatures(fixture_path("signed"))
  parsed <- pdf_parse_date(res$time)
  expect_s3_class(parsed, "POSIXct")
  expect_equal(
    format(parsed, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    "2026-05-16 00:00:00"
  )
})
