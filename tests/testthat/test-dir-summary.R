# Tests for pdf_dir_summary() — the bulk-triage helper that wraps
# pdf_doc_summary() over every PDF in a directory.

# Helper to expose the shipped fixture directory.
fixture_dir <- function() {
  system.file("extdata", "fixtures", package = "pdfium")
}

test_that("pdf_dir_summary returns a tibble with one row per PDF", {
  s <- pdf_dir_summary(fixture_dir())
  expect_s3_class(s, "tbl_df")
  files <- list.files(fixture_dir(), pattern = "\\.pdf$")
  expect_equal(nrow(s), length(files))
})

test_that("pdf_dir_summary column shape matches pdf_doc_summary", {
  bulk <- pdf_dir_summary(fixture_dir())
  one  <- pdf_doc_summary(fixture_path("shapes"))
  expect_named(bulk, names(one))
})

test_that("pdf_dir_summary preserves the path column", {
  s <- pdf_dir_summary(fixture_dir())
  expect_true(all(grepl("\\.pdf$", s$path)))
  expect_true(all(file.exists(s$path)))
})

test_that("pdf_dir_summary recursive descent works", {
  # Create a nested temp dir with two PDFs, one in a subdir.
  tmp <- withr::local_tempdir()
  file.copy(fixture_path("minimal"), file.path(tmp, "top.pdf"))
  sub <- file.path(tmp, "subdir")
  dir.create(sub)
  file.copy(fixture_path("minimal"), file.path(sub, "nested.pdf"))

  flat <- pdf_dir_summary(tmp, recursive = FALSE)
  expect_equal(nrow(flat), 1L)

  deep <- pdf_dir_summary(tmp, recursive = TRUE)
  expect_equal(nrow(deep), 2L)
})

test_that("pdf_dir_summary returns zero rows for an empty dir", {
  tmp <- withr::local_tempdir()
  s <- pdf_dir_summary(tmp)
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 0L)
})

test_that("pdf_dir_summary's empty tibble has the right shape", {
  empty <- pdfium:::pdf_doc_summary_empty()
  expect_s3_class(empty, "tbl_df")
  expect_equal(nrow(empty), 0L)
  one <- pdf_doc_summary(fixture_path("shapes"))
  expect_named(empty, names(one))
})

test_that("pdf_dir_summary case-insensitive PDF pattern matches .PDF too", {
  tmp <- withr::local_tempdir()
  file.copy(fixture_path("minimal"), file.path(tmp, "upper.PDF"))
  file.copy(fixture_path("minimal"), file.path(tmp, "lower.pdf"))
  s <- pdf_dir_summary(tmp)
  expect_equal(nrow(s), 2L)
})

test_that("pdf_dir_summary errors = stop aborts on a bad file", {
  tmp <- withr::local_tempdir()
  file.copy(fixture_path("minimal"), file.path(tmp, "good.pdf"))
  writeLines("not a pdf", file.path(tmp, "bad.pdf"))
  expect_error(
    pdf_dir_summary(tmp, errors = "stop"),
    "failed to read"
  )
})

test_that("pdf_dir_summary errors = warn drops bad files with a warning", {
  tmp <- withr::local_tempdir()
  file.copy(fixture_path("minimal"), file.path(tmp, "good.pdf"))
  writeLines("not a pdf", file.path(tmp, "bad.pdf"))
  s <- suppressWarnings(pdf_dir_summary(tmp, errors = "warn"))
  expect_equal(nrow(s), 1L)
  expect_warning(
    pdf_dir_summary(tmp, errors = "warn"),
    "failed to read"
  )
})

test_that("pdf_dir_summary errors = skip silently drops bad files", {
  tmp <- withr::local_tempdir()
  file.copy(fixture_path("minimal"), file.path(tmp, "good.pdf"))
  writeLines("not a pdf", file.path(tmp, "bad.pdf"))
  expect_no_warning(s <- pdf_dir_summary(tmp, errors = "skip"))
  expect_equal(nrow(s), 1L)
})

test_that("pdf_dir_summary returns zero rows when every file fails", {
  tmp <- withr::local_tempdir()
  writeLines("not a pdf", file.path(tmp, "bad1.pdf"))
  writeLines("also not a pdf", file.path(tmp, "bad2.pdf"))
  s <- suppressWarnings(pdf_dir_summary(tmp, errors = "skip"))
  expect_equal(nrow(s), 0L)
})

test_that("pdf_dir_summary forwards the password argument", {
  s <- pdf_dir_summary(fixture_dir(), password = NULL)
  expect_gt(nrow(s), 0L)
})

test_that("pdf_dir_summary rejects bad inputs", {
  expect_error(pdf_dir_summary("/this/path/does/not/exist"),
               "Assertion on")
  expect_error(pdf_dir_summary(fixture_dir(), pattern = NA_character_),
               "Assertion on")
  expect_error(pdf_dir_summary(fixture_dir(), recursive = "yes"),
               "Assertion on")
  expect_error(pdf_dir_summary(fixture_dir(), errors = "bogus"),
               "'arg' should be one of")
})

test_that("pdf_dir_summary respects a custom pattern", {
  # Only match the annotated fixture.
  s <- pdf_dir_summary(fixture_dir(), pattern = "^annotated\\.pdf$")
  expect_equal(nrow(s), 1L)
  expect_match(s$path[[1L]], "annotated\\.pdf$")
})
