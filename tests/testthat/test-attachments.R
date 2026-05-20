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
