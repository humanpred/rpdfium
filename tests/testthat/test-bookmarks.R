# Tests for pdf_bookmarks(), pdf_page_label(), pdf_page_labels(),
# and pdf_doc_permissions(). outline.pdf is a hand-built two-page
# fixture with:
#
#   Chapter 1     (level 1, page 1)
#     Section 1.1 (level 2, page 1)
#     Section 1.2 (level 2, page 2)
#
# and PageLabels mapping page 1 -> "i", page 2 -> "1".
# shapes.pdf is a Cairo PDF with no outline / no labels and is
# unencrypted; we use it for the empty-tree and all-permissions
# branches.

# pdf_bookmarks ----------------------------------------------------

test_that("pdf_bookmarks() returns the documented tibble shape", {
  doc <- pdf_open(fixture_path("outline"))
  on.exit(pdf_close(doc), add = TRUE)
  bm <- pdf_bookmarks(doc)
  expect_s3_class(bm, "tbl_df")
  expect_named(bm, c("bookmark_index", "parent_index", "level",
                     "title", "page_num"))
  expect_type(bm$bookmark_index, "integer")
  expect_type(bm$parent_index,   "integer")
  expect_type(bm$level,          "integer")
  expect_type(bm$title,          "character")
  expect_type(bm$page_num,       "integer")
})

test_that("pdf_bookmarks() reads the outline tree depth-first", {
  bm <- pdf_bookmarks(fixture_path("outline"))
  expect_equal(nrow(bm), 3L)
  expect_identical(bm$bookmark_index, 1L:3L)
  expect_identical(bm$title,
                   c("Chapter 1", "Section 1.1", "Section 1.2"))
  expect_identical(bm$level,        c(1L, 2L, 2L))
  expect_identical(bm$parent_index, c(0L, 1L, 1L))
  expect_identical(bm$page_num,     c(1L, 1L, 2L))
})

test_that("pdf_bookmarks() returns 0 rows for a PDF without an outline", {
  bm <- pdf_bookmarks(fixture_path("shapes"))
  expect_s3_class(bm, "tbl_df")
  expect_equal(nrow(bm), 0L)
  expect_named(bm, c("bookmark_index", "parent_index", "level",
                     "title", "page_num"))
})

test_that("pdf_bookmarks() accepts a path or an open doc", {
  by_path <- pdf_bookmarks(fixture_path("outline"))
  doc <- pdf_open(fixture_path("outline"))
  on.exit(pdf_close(doc), add = TRUE)
  by_doc  <- pdf_bookmarks(doc)
  expect_identical(by_path$title, by_doc$title)
  expect_true(is_open(doc))
})

test_that("pdf_bookmarks() rejects bad inputs and closed docs", {
  expect_error(pdf_bookmarks(42), "must be a `pdfium_doc` or a path")
  doc <- pdf_open(fixture_path("outline"))
  pdf_close(doc)
  expect_error(pdf_bookmarks(doc), "Document has been closed")
})

# pdf_page_label / pdf_page_labels ---------------------------------

test_that("pdf_page_labels() reads the PageLabels number tree", {
  expect_identical(pdf_page_labels(fixture_path("outline")),
                   c("i", "1"))
})

test_that("pdf_page_label() reads one page's label", {
  doc <- pdf_open(fixture_path("outline"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_identical(pdf_page_label(doc, 1L), "i")
  expect_identical(pdf_page_label(doc, 2L), "1")
})

test_that("pdf_page_labels() returns empty strings for PDFs without a labels table", {
  # shapes.pdf has no /PageLabels entry. PDFium returns the empty
  # string for every page rather than synthesising a label.
  labs <- pdf_page_labels(fixture_path("shapes"))
  expect_length(labs, 1L)
  expect_identical(labs, "")
})

test_that("pdf_page_label() validates page_num", {
  doc <- pdf_open(fixture_path("outline"))
  on.exit(pdf_close(doc), add = TRUE)
  expect_error(pdf_page_label(doc, 0),
               "must be a single positive integer")
  expect_error(pdf_page_label(doc, -1),
               "must be a single positive integer")
  expect_error(pdf_page_label(doc, 1.5),
               "must be a single positive integer")
  expect_error(pdf_page_label(doc, NA_integer_),
               "must be a single positive integer")
  expect_error(pdf_page_label(doc, c(1, 2)),
               "must be a single positive integer")
})

# pdf_doc_permissions ---------------------------------------------

test_that("pdf_doc_permissions() reports all flags TRUE for an unencrypted PDF", {
  p <- pdf_doc_permissions(fixture_path("shapes"))
  expect_type(p, "logical")
  expect_named(p, c("print", "modify", "copy", "annotate",
                    "fill_forms", "extract_for_a11y", "assemble",
                    "print_high_res"))
  expect_true(all(p))
})

test_that("pdf_doc_permissions() accepts a path or an open doc", {
  by_path <- pdf_doc_permissions(fixture_path("shapes"))
  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  by_doc  <- pdf_doc_permissions(doc)
  expect_identical(by_path, by_doc)
})

test_that("pdf_doc_permissions() rejects closed docs", {
  doc <- pdf_open(fixture_path("shapes"))
  pdf_close(doc)
  expect_error(pdf_doc_permissions(doc), "Document has been closed")
})
