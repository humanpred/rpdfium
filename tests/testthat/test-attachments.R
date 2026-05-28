# Tests for pdf_attachments() (now returns a pdfium_attachment_list).
# attachments.pdf is a hand-built fixture with a single
# text/plain attachment "hello.txt" carrying the bytes
# "hello world\n" (12 bytes).

test_that("pdf_attachments returns 0 handles for a doc with no attachments", {
  res <- pdf_attachments(fixture_path("shapes"))
  expect_s3_class(res, "pdfium_attachment_list")
  expect_length(res, 0L)
  tbl <- tibble::as_tibble(res)
  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 0L)
  expect_named(tbl, c("attachment_index", "name", "mime_type",
                      "size_bytes", "handle", "source"))
})

test_that("pdf_attachments reports the documented attachment", {
  res <- tibble::as_tibble(pdf_attachments(fixture_path("attachments")))
  expect_equal(nrow(res), 1L)
  expect_identical(res$attachment_index, 1L)
  expect_identical(res$name, "hello.txt")
  expect_identical(res$mime_type, "text/plain")
  expect_identical(res$size_bytes, 12)
})

test_that("pdf_attachment_data returns the embedded bytes verbatim", {
  atts <- pdf_attachments(fixture_path("attachments"))
  data <- pdf_attachment_data(atts[[1L]])
  expect_type(data, "raw")
  expect_length(data, 12L)
  expect_identical(rawToChar(data), "hello world\n")
})

test_that("pdf_attachments accepts a path or an open doc", {
  by_path <- tibble::as_tibble(
    pdf_attachments(fixture_path("attachments"))
  )
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- tibble::as_tibble(pdf_attachments(doc))
  drop_handle <- function(t) {
    t[, !names(t) %in% c("handle", "source")]
  }
  expect_identical(drop_handle(by_path), drop_handle(by_doc))
})

test_that("pdf_attachment_data rejects non-attachment input", {
  expect_error(pdf_attachment_data("nope"), "Assertion on")
  expect_error(pdf_attachment_data(42L), "Assertion on")
  expect_error(pdf_attachment_data(NULL), "Assertion on")
})

test_that("pdf_attachments rejects bad inputs and closed docs", {
  expect_error(pdf_attachments(42), "class .pdfium_doc.")
  doc <- pdf_doc_open(fixture_path("attachments"))
  pdf_doc_close(doc)
  expect_error(pdf_attachments(doc), "Document has been closed")
})

# -- New handle-based tests --

test_that("pdf_attachments returns a list of pdfium_attachment handles", {
  atts <- pdf_attachments(fixture_path("attachments"))
  expect_s3_class(atts, "pdfium_attachment_list")
  expect_length(atts, 1L)
  expect_s3_class(atts[[1L]], "pdfium_attachment")
})

test_that("per-handle attachment getters work", {
  atts <- pdf_attachments(fixture_path("attachments"))
  a <- atts[[1L]]
  expect_equal(pdf_attachment_name(a), "hello.txt")
  expect_equal(pdf_attachment_mime_type(a), "text/plain")
  expect_equal(pdf_attachment_size_bytes(a), 12)
  expect_identical(rawToChar(pdf_attachment_data(a)), "hello world\n")
})

test_that("pdfium_attachment print method shows name + index", {
  atts <- pdf_attachments(fixture_path("attachments"))
  out <- capture.output(print(atts[[1L]]))
  expect_true(any(grepl("hello.txt", out)))
  expect_true(any(grepl("idx 1", out)))
})

test_that("pdfium_attachment_list print shows count", {
  atts <- pdf_attachments(fixture_path("attachments"))
  txt <- capture.output(print(atts))
  expect_true(any(grepl("1 attachment\\(s\\)", txt)))
})

test_that("pdfium_attachment_list print truncates beyond 5 entries", {
  atts <- pdf_attachments(fixture_path("attachments"))
  # Replicate the single attachment six times to exercise the
  # "... and N more" branch.
  many <- structure(
    rep(unclass(atts), 6L),
    source = attr(atts, "source"),
    class = c("pdfium_attachment_list", "list")
  )
  txt <- capture.output(print(many))
  expect_true(any(grepl("more", txt)))
})

test_that("as_pdfium_attachment_list round-trips from tibble", {
  atts <- pdf_attachments(fixture_path("attachments"))
  tbl <- tibble::as_tibble(atts)
  back <- as_pdfium_attachment_list(tbl)
  expect_s3_class(back, "pdfium_attachment_list")
  expect_length(back, length(atts))
  expect_identical(back[[1L]]$ptr, atts[[1L]]$ptr)
})

test_that("as_pdfium_attachment_list is a no-op on existing handle lists", {
  atts <- pdf_attachments(fixture_path("attachments"))
  expect_identical(as_pdfium_attachment_list(atts), atts)
})

test_that("as_pdfium_attachment_list accepts a plain list of handles", {
  atts <- pdf_attachments(fixture_path("attachments"))
  plain <- unclass(atts)
  back <- as_pdfium_attachment_list(plain)
  expect_s3_class(back, "pdfium_attachment_list")
})

test_that("as_pdfium_attachment_list errors on unrecognised input", {
  expect_error(as_pdfium_attachment_list("nope"),
               "must be a .pdfium_attachment_list.")
  expect_error(
    as_pdfium_attachment_list(tibble::tibble(handle = list(),
                                              source = list())),
    "zero-row"
  )
})

test_that("per-handle getters reject non-attachment input", {
  expect_error(pdf_attachment_name("nope"), "Assertion on")
  expect_error(pdf_attachment_mime_type(42), "Assertion on")
  expect_error(pdf_attachment_size_bytes(NULL), "Assertion on")
})

test_that("attachment handle invalidates when its parent doc closes", {
  doc <- pdf_doc_open(fixture_path("attachments"))
  atts <- pdf_attachments(doc)
  a <- atts[[1L]]
  expect_true(is_open(a))
  pdf_doc_close(doc)
  expect_false(is_open(a))
  expect_error(pdf_attachment_name(a), "has been closed")
})

test_that("pdf_attachment_dict_value works on a handle", {
  atts <- pdf_attachments(fixture_path("attachments"))
  out <- pdf_attachment_dict_value(atts[[1L]], "Subtype")
  expect_named(out, c("has_key", "value_type", "value"))
  # The fixture's attachment-dict shape (whether /Subtype is in the
  # dict or only in the /F filespec) varies by PDFium version. The
  # generic shape is what matters here; specific key presence is
  # tested via the structured `pdf_attachment_mime_type()` reader.
  expect_type(out$has_key, "logical")
  expect_type(out$value_type, "integer")
})

test_that("pdf_attachment_dict_value reports has_key=FALSE for missing keys", {
  atts <- pdf_attachments(fixture_path("attachments"))
  out <- pdf_attachment_dict_value(atts[[1L]], "NoSuchKey")
  expect_false(out$has_key)
  expect_true(is.na(out$value_type))
})

test_that("pdf_attachment_dict_value validates inputs", {
  atts <- pdf_attachments(fixture_path("attachments"))
  expect_error(
    pdf_attachment_dict_value(atts[[1L]], ""),
    "Assertion on"
  )
  expect_error(
    pdf_attachment_dict_value("not-an-attachment", "Subtype"),
    "Assertion on"
  )
})

# Direct-shim coverage for the legacy bulk readers in attachments.cpp
# that the per-handle pdf_attachment_*() API has superseded.

test_that("cpp_attachments_list reports the documented attachment", {
  # The R-side as_tibble.pdfium_attachment_list() calls this shim
  # for non-empty lists, but going through the higher-level path
  # leaves a few lines on cpp_attachments_list / cpp_attachment_data
  # untested. Direct invocation exercises both end-to-end.
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  out <- pdfium:::cpp_attachments_list(doc$ptr)
  expect_named(out, c("name", "mime_type", "size_bytes"))
  expect_identical(out$name, "hello.txt")
  expect_identical(out$mime_type, "text/plain")
  expect_identical(out$size_bytes, 12)
})

test_that("cpp_attachment_data returns the embedded bytes verbatim", {
  # The high-level pdf_attachment_data() now calls
  # cpp_attachment_data_handle (attachment_handles.cpp). The legacy
  # doc-index variant in attachments.cpp is reached only via the
  # direct shim.
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  data <- pdfium:::cpp_attachment_data(doc$ptr, 0L)
  expect_type(data, "raw")
  expect_length(data, 12L)
  expect_identical(rawToChar(data), "hello world\n")
})

test_that("cpp_attachment_get rejects an out-of-range index", {
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(
    pdfium:::cpp_attachment_get(doc$ptr, 99L),
    "returned NULL"
  )
})

test_that("cpp_attachment_has_key_handle reports key presence", {
  # Exported-but-unused shim from src/attachment_handles.cpp. The
  # production reader (cpp_attachment_dict_value_handle) returns
  # has_key alongside the value; this lighter shim is kept available
  # for callers that only need the existence check.
  atts <- pdf_attachments(fixture_path("attachments"))
  # Pick a key that the fixture's filespec dict shape guarantees we
  # can probe either way — "Type" is universal on filespec dicts.
  res_missing <- pdfium:::cpp_attachment_has_key_handle(
    atts[[1L]]$ptr, "DefinitelyNotAKey"
  )
  expect_false(res_missing)
})
