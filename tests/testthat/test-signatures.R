# Tests for pdf_signatures() (now returns a pdfium_signature_list)
# and the handle-based per-attribute getters. signed.pdf is a
# hand-built fixture carrying ONE signature widget annotation with:
#   /SubFilter is "adbe.pkcs7.detached" (ASCII)
#   /Reason    is "Test" (UTF-16BE BOM + chars)
#   /M (time)  is "D:20260516000000+00'00'"
#   /Contents  is the 4-byte placeholder 0xDEADBEEF
#   /ByteRange is [0 100 200 300] (two pairs)

test_that("pdf_signatures returns 0 handles for an unsigned doc", {
  res <- pdf_signatures(fixture_path("shapes"))
  expect_s3_class(res, "pdfium_signature_list")
  expect_length(res, 0L)
  tbl <- tibble::as_tibble(res)
  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 0L)
  expect_named(tbl, c(
    "signature_index", "sub_filter", "reason",
    "time", "doc_mdp_permission", "contents_size",
    "byte_range_pairs", "handle", "source"
  ))
})

test_that("pdf_signatures reports the documented signature", {
  res <- tibble::as_tibble(pdf_signatures(fixture_path("signed")))
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
  sigs <- pdf_signatures(fixture_path("signed"))
  raw <- pdf_signature_contents(sigs[[1L]])
  expect_type(raw, "raw")
  expect_length(raw, 4L)
  expect_identical(
    as.integer(raw),
    c(0xDEL, 0xADL, 0xBEL, 0xEFL)
  )
})

test_that("pdf_signature_byte_range returns the documented matrix", {
  sigs <- pdf_signatures(fixture_path("signed"))
  m <- pdf_signature_byte_range(sigs[[1L]])
  expect_true(is.matrix(m))
  expect_equal(dim(m), c(2L, 2L))
  expect_identical(colnames(m), c("offset", "length"))
  expect_identical(m[1L, ], c(offset = 0L, length = 100L))
  expect_identical(m[2L, ], c(offset = 200L, length = 300L))
})

test_that("pdf_signatures accepts a path or an open doc", {
  by_path <- tibble::as_tibble(pdf_signatures(fixture_path("signed")))
  doc <- pdf_doc_open(fixture_path("signed"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- tibble::as_tibble(pdf_signatures(doc))
  drop_handle <- function(t) {
    t[, !names(t) %in% c("handle", "source")]
  }
  expect_identical(drop_handle(by_path), drop_handle(by_doc))
})

test_that("pdf_signature_contents / _byte_range reject non-handle input", {
  expect_error(pdf_signature_contents("nope"), "Assertion on")
  expect_error(pdf_signature_byte_range(42L), "Assertion on")
})

test_that("pdf_signatures rejects bad inputs and closed docs", {
  expect_error(pdf_signatures(42), "class .pdfium_doc.")
  doc <- pdf_doc_open(fixture_path("signed"))
  pdf_doc_close(doc)
  expect_error(pdf_signatures(doc), "Document has been closed")
})

test_that("the time column round-trips through pdf_parse_date", {
  res <- tibble::as_tibble(pdf_signatures(fixture_path("signed")))
  parsed <- pdf_parse_date(res$time)
  expect_s3_class(parsed, "POSIXct")
  expect_equal(
    format(parsed, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    "2026-05-16 00:00:00"
  )
})

# -- New handle-based tests --

test_that("pdf_signatures returns a list of pdfium_signature handles", {
  sigs <- pdf_signatures(fixture_path("signed"))
  expect_s3_class(sigs, "pdfium_signature_list")
  expect_length(sigs, 1L)
  expect_s3_class(sigs[[1L]], "pdfium_signature")
})

test_that("per-handle signature getters work", {
  sigs <- pdf_signatures(fixture_path("signed"))
  s <- sigs[[1L]]
  expect_equal(pdf_signature_sub_filter(s), "adbe.pkcs7.detached")
  expect_equal(pdf_signature_reason(s), "Test")
  expect_equal(pdf_signature_time(s), "D:20260516000000+00'00'")
  expect_true(is.na(pdf_signature_doc_mdp_permission(s)))
})

test_that("pdfium_signature print shows sub-filter + index", {
  sigs <- pdf_signatures(fixture_path("signed"))
  out <- capture.output(print(sigs[[1L]]))
  expect_true(any(grepl("adbe.pkcs7.detached", out)))
})

test_that("pdfium_signature_list print shows count", {
  sigs <- pdf_signatures(fixture_path("signed"))
  txt <- capture.output(print(sigs))
  expect_true(any(grepl("1 signature\\(s\\)", txt)))
})

test_that("pdfium_signature_list print truncates beyond 5 entries", {
  sigs <- pdf_signatures(fixture_path("signed"))
  many <- structure(
    rep(unclass(sigs), 6L),
    source = attr(sigs, "source"),
    class = c("pdfium_signature_list", "list")
  )
  txt <- capture.output(print(many))
  expect_true(any(grepl("more", txt)))
})

test_that("as_pdfium_signature_list round-trips from tibble", {
  sigs <- pdf_signatures(fixture_path("signed"))
  tbl <- tibble::as_tibble(sigs)
  back <- as_pdfium_signature_list(tbl)
  expect_s3_class(back, "pdfium_signature_list")
  expect_identical(back[[1L]]$ptr, sigs[[1L]]$ptr)
})

test_that("as_pdfium_signature_list is a no-op on existing handle lists", {
  sigs <- pdf_signatures(fixture_path("signed"))
  expect_identical(as_pdfium_signature_list(sigs), sigs)
})

test_that("as_pdfium_signature_list accepts a plain list of handles", {
  sigs <- pdf_signatures(fixture_path("signed"))
  plain <- unclass(sigs)
  back <- as_pdfium_signature_list(plain)
  expect_s3_class(back, "pdfium_signature_list")
})

test_that("as_pdfium_signature_list errors on unrecognised input", {
  expect_error(as_pdfium_signature_list("nope"),
               "must be a .pdfium_signature_list.")
  expect_error(
    as_pdfium_signature_list(tibble::tibble(handle = list(),
                                             source = list())),
    "zero-row"
  )
})

test_that("per-handle signature getters reject non-signature input", {
  expect_error(pdf_signature_sub_filter("nope"), "Assertion on")
  expect_error(pdf_signature_reason(42), "Assertion on")
  expect_error(pdf_signature_time(NULL), "Assertion on")
  expect_error(pdf_signature_doc_mdp_permission(0L), "Assertion on")
})

test_that("signature handle invalidates when its parent doc closes", {
  doc <- pdf_doc_open(fixture_path("signed"))
  sigs <- pdf_signatures(doc)
  s <- sigs[[1L]]
  expect_true(is_open(s))
  pdf_doc_close(doc)
  expect_false(is_open(s))
  expect_error(pdf_signature_sub_filter(s), "has been closed")
})
