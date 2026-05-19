# Tests for pdf_structure_tree(). tagged.pdf is a hand-built single-
# page PDF whose catalog declares a /StructTreeRoot containing a
# Document element with three children (H1 / P / Figure). Only the
# P element has marked content on the page (MCID 0), so PDFium's
# per-page view of the tree (FPDF_StructTree_GetForPage) surfaces
# just the Document + P pair — H1 and Figure are filtered out
# because they have no content on this page.

test_that("pdf_structure_tree returns 0 rows for an untagged PDF", {
  for (name in c("shapes", "minimal", "annotated")) {
    out <- pdf_structure_tree(pdf_open(fixture_path(name)), 1L)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
    expect_named(out, c("element_index", "parent_index", "level",
                        "type", "obj_type", "title", "lang",
                        "alt_text", "actual_text", "id",
                        "mcid", "mcid_count", "attributes"))
  }
})

test_that("pdf_structure_tree walks the tagged-PDF tree", {
  doc <- pdf_open(fixture_path("tagged"))
  on.exit(pdf_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, page_num = 1L)
  expect_s3_class(res, "tbl_df")
  # PDFium's per-page view only returns elements with content on
  # the page (Document + P). H1 and Figure are filtered out.
  expect_equal(nrow(res), 2L)
  expect_identical(res$element_index, 1L:2L)
  expect_identical(res$type, c("Document", "P"))
  expect_identical(res$parent_index, c(0L, 1L))
  expect_identical(res$level,        c(1L, 2L))
  # P has marked content (/MCR with MCID 0); Document does not.
  expect_true(is.na(res$mcid[[1L]]))
  expect_equal(res$mcid[[2L]], 0L)
  expect_equal(res$mcid_count[[1L]], 0L)
  expect_equal(res$mcid_count[[2L]], 1L)
})

test_that("pdf_structure_tree accepts a doc + page_num or a page", {
  doc <- pdf_open(fixture_path("tagged"))
  on.exit(pdf_close(doc), add = TRUE)
  by_doc <- pdf_structure_tree(doc, page_num = 1L)
  page <- pdf_load_page(doc, 1L)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)
  by_page <- pdf_structure_tree(page)
  expect_identical(by_doc, by_page)
})

test_that("pdf_structure_tree rejects bad inputs and closed pages", {
  expect_error(pdf_structure_tree("nope"),
               "must be a `pdfium_page` or a `pdfium_doc`")
  doc <- pdf_open(fixture_path("tagged"))
  page <- pdf_load_page(doc, 1L)
  pdf_close_page(page)
  expect_error(pdf_structure_tree(page), "closed")
  pdf_close(doc)
})
