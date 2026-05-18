# Tests for the doc-level readouts added in the 0.1.0
# read-completion pass: is_tagged, viewer_preferences, named_dests,
# doc_javascript. The bundled fixtures don't set these to non-default
# values (shapes.pdf is a plain Cairo render; outline.pdf has
# bookmarks but no /Names, ViewerPreferences, JS, or MarkInfo), so
# these tests focus on shape/type guarantees and the path-vs-doc
# fork. Behaviour-with-content is covered by manual / vignette use.

test_that("pdf_doc_is_tagged returns FALSE on plain Cairo fixtures", {
  for (name in c("shapes", "outline", "annotated", "minimal")) {
    out <- pdf_doc_is_tagged(fixture_path(name))
    expect_type(out, "logical")
    expect_length(out, 1L)
    expect_false(out)
  }
})

test_that("pdf_doc_is_tagged accepts doc or path equivalently", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_identical(pdf_doc_is_tagged(doc),
                   pdf_doc_is_tagged(fixture_path("shapes")))
})

test_that("pdf_doc_is_tagged rejects bad inputs and closed docs", {
  expect_error(pdf_doc_is_tagged(42), "must be a `pdfium_doc`")
  doc <- pdf_open(fixture_path("shapes"))
  pdf_close(doc)
  expect_error(pdf_doc_is_tagged(doc), "closed")
})

test_that("pdf_viewer_preferences reports PDFium defaults on fixtures", {
  prefs <- pdf_viewer_preferences(fixture_path("shapes"))
  expect_named(prefs, c("print_scaling", "num_copies", "duplex",
                        "print_page_ranges"))
  expect_type(prefs$print_scaling, "logical")
  expect_length(prefs$print_scaling, 1L)
  expect_type(prefs$num_copies, "integer")
  expect_length(prefs$num_copies, 1L)
  expect_true(prefs$num_copies >= 1L)
  expect_type(prefs$duplex, "character")
  expect_true(prefs$duplex %in%
              c("none", "simplex",
                "duplex_flip_short_edge", "duplex_flip_long_edge"))
  expect_type(prefs$print_page_ranges, "integer")
})

test_that("pdf_viewer_preferences accepts doc or path", {
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_identical(pdf_viewer_preferences(doc),
                   pdf_viewer_preferences(fixture_path("shapes")))
})

test_that("pdf_named_dests returns an empty tibble of the right shape", {
  out <- pdf_named_dests(fixture_path("shapes"))
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("name", "page"))
  expect_type(out$name, "character")
  expect_type(out$page, "integer")
})

test_that("pdf_named_dests rejects bad doc inputs", {
  expect_error(pdf_named_dests(list()), "must be a `pdfium_doc`")
  doc <- pdf_open(fixture_path("shapes"))
  pdf_close(doc)
  expect_error(pdf_named_dests(doc), "closed")
})

test_that("pdf_doc_javascript returns an empty tibble for JS-free PDFs", {
  out <- pdf_doc_javascript(fixture_path("shapes"))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("name", "script"))
  expect_type(out$name, "character")
  expect_type(out$script, "character")
})

test_that("pdf_doc_javascript accepts doc or path", {
  doc <- pdf_open(fixture_path("outline"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_identical(pdf_doc_javascript(doc),
                   pdf_doc_javascript(fixture_path("outline")))
})
