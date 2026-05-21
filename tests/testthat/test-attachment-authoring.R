# Tests for the Phase 8 attachment authoring API:
# pdf_attachment_new, _delete, _set_dict_value, _set_data.
# The shipped `attachments.pdf` fixture has one attachment
# ("hello.txt", text/plain, 12 bytes).

# pdf_attachment_new -----------------------------------------------

test_that("pdf_attachment_new adds a new attachment to a doc", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  before <- length(pdf_attachments(doc))
  att <- pdf_attachment_new(doc, "added.bin")
  expect_s3_class(att, "pdfium_attachment")
  expect_identical(att$index, before + 1L)
  expect_identical(pdf_attachment_name(att), "added.bin")
  # And the list grew by one.
  after <- pdf_attachments(doc)
  expect_length(after, before + 1L)
})

test_that("pdf_attachment_new rejects duplicate / empty names", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_attachment_new(doc, "hello.txt"),
               "FPDFDoc_AddAttachment returned NULL")
  expect_error(pdf_attachment_new(doc, ""), "Assertion on")
})

test_that("pdf_attachment_new accepts UTF-8 filenames", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  nm <- enc2utf8("日本語.txt")
  att <- pdf_attachment_new(doc, nm)
  expect_identical(pdf_attachment_name(att), nm)
})

test_that("pdf_attachment_new rejects bad inputs", {
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # Read-only doc.
  expect_error(pdf_attachment_new(doc, "x.bin"), "readwrite")
  # Bad doc type.
  expect_error(pdf_attachment_new("nope", "x.bin"), "Assertion on")
  # Bad name type.
  doc_rw <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc_rw), add = TRUE)
  expect_error(pdf_attachment_new(doc_rw, NA_character_), "Assertion on")
  expect_error(pdf_attachment_new(doc_rw, 42L), "Assertion on")
})

# pdf_attachment_delete --------------------------------------------

test_that("pdf_attachment_delete removes an attachment", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  atts <- pdf_attachments(doc)
  expect_length(atts, 1L)
  ret <- pdf_attachment_delete(atts[[1L]])
  expect_identical(ret, doc)
  # The doc now reports zero attachments.
  expect_length(pdf_attachments(doc), 0L)
  # The handle's underlying ptr is now NULL; subsequent reads
  # error via the handle_validation guard.
  expect_error(pdf_attachment_name(atts[[1L]]), "has been closed")
})

test_that("pdf_attachment_delete refuses a read-only doc", {
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  expect_error(pdf_attachment_delete(att), "readwrite")
})

# pdf_attachment_set_dict_value ------------------------------------

# Helper: open the attachments fixture readwrite and prep its single
# attachment so /Params exists (PDFium's SetStringValue requires it).
# Reuses the existing payload's text content.
fresh_writable_attachment <- function(envir = parent.frame()) {
  # `fixture_path()` lives in helper-fixtures.R; lintr can't see it
  # from this helper's body.
  doc <- pdf_doc_open(fixture_path("attachments"),  # nolint
                      readwrite = TRUE)
  withr::defer(pdf_doc_close(doc), envir = envir)
  att <- pdf_attachments(doc)[[1L]]
  # Re-write the same bytes; this is the documented way to materialise
  # /Params (SetFile auto-creates Size/CreationDate/CheckSum entries).
  pdf_attachment_set_data(att, pdf_attachment_data(att))
  list(doc = doc, att = att)
}

test_that("pdf_attachment_set_dict_value writes a /Params entry", {
  s <- fresh_writable_attachment()
  ret <- pdf_attachment_set_dict_value(s$att, "Desc", "a description")
  expect_identical(ret, s$doc)
  read <- pdf_attachment_dict_value(s$att, "Desc")
  expect_true(read$has_key)
  expect_identical(read$value, "a description")
})

test_that("pdf_attachment_set_dict_value round-trips ASCII", {
  # Note: PDFium's FPDFAttachment_SetStringValue stores the value
  # as a PDF byte-string (PDFDocEncoding), not as UTF-16BE+BOM
  # (which is what FPDFAnnot_SetStringValue does). High Unicode
  # characters survive write-then-read but get mangled on the way
  # back through the PDFDocEncoding-decoding GetUnicodeText() path.
  # This is an upstream PDFium inconsistency. ASCII round-trips
  # cleanly; non-ASCII is best-effort until upstream is fixed.
  s <- fresh_writable_attachment()
  msg <- "Quarterly revenue and gross margin summary"
  pdf_attachment_set_dict_value(s$att, "Desc", msg)
  expect_identical(pdf_attachment_dict_value(s$att, "Desc")$value, msg)
})

test_that("pdf_attachment_set_dict_value rejects bad inputs", {
  s <- fresh_writable_attachment()
  expect_error(pdf_attachment_set_dict_value(s$att, "", "x"),
               "Assertion on")
  expect_error(pdf_attachment_set_dict_value(s$att, "K", NA_character_),
               "Assertion on")
  expect_error(pdf_attachment_set_dict_value(s$att, "K", 42L),
               "Assertion on")
})

test_that("pdf_attachment_set_dict_value refuses read-only doc", {
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  expect_error(pdf_attachment_set_dict_value(att, "Desc", "x"),
               "readwrite")
})

# pdf_attachment_set_data ------------------------------------------

test_that("pdf_attachment_set_data writes raw bytes", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  new_bytes <- charToRaw("replaced contents")
  ret <- pdf_attachment_set_data(att, new_bytes)
  expect_identical(ret, doc)
  # The read side returns the new bytes.
  read_back <- pdf_attachment_data(att)
  expect_identical(read_back, new_bytes)
})

test_that("pdf_attachment_set_data round-trips a binary blob", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  payload <- as.raw(0:255)
  pdf_attachment_set_data(att, payload)
  expect_identical(pdf_attachment_data(att), payload)
})

test_that("pdf_attachment_set_data populates a fresh attachment", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachment_new(doc, "fresh.bin")
  payload <- charToRaw("brand new contents")
  pdf_attachment_set_data(att, payload)
  expect_identical(pdf_attachment_data(att), payload)
})

test_that("pdf_attachment_set_data rejects bad inputs", {
  doc <- pdf_doc_open(fixture_path("attachments"), readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  expect_error(pdf_attachment_set_data(att, "not raw"),
               "Assertion on")
  expect_error(pdf_attachment_set_data(att, 1:5), "Assertion on")
})

test_that("pdf_attachment_set_data refuses read-only doc", {
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachments(doc)[[1L]]
  expect_error(pdf_attachment_set_data(att, charToRaw("x")),
               "readwrite")
})

# Round-trip via pdf_save ------------------------------------------

test_that("attachment authoring round-trips through pdf_save", {
  src <- fixture_path("attachments")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  doc <- pdf_doc_open(src, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  att <- pdf_attachment_new(doc, "added.bin")
  pdf_attachment_set_data(att, charToRaw("new payload"))
  # /Params/Desc round-trips; the file-stream /Subtype (read by
  # pdf_attachment_mime_type) is not writable via PDFium's public
  # API and stays empty on attachments built this way. See the
  # function's @details for the upstream gap.
  pdf_attachment_set_dict_value(att, "Desc", "freshly added")
  pdf_save(doc, tmp)

  # Re-open and verify.
  doc2 <- pdf_doc_open(tmp)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  atts2 <- pdf_attachments(doc2)
  expect_length(atts2, 2L)
  names <- vapply(atts2, pdf_attachment_name, character(1L))
  expect_setequal(names, c("hello.txt", "added.bin"))
  added <- atts2[[which(names == "added.bin")]]
  expect_identical(pdf_attachment_data(added), charToRaw("new payload"))
  expect_identical(pdf_attachment_dict_value(added, "Desc")$value,
                   "freshly added")
})
