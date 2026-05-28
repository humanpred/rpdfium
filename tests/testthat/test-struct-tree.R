# Tests for pdf_structure_tree(). tagged.pdf is a hand-built single-
# page PDF whose catalog declares a /StructTreeRoot containing a
# Document element with three children (H1 / P / Figure). Only the
# P element has marked content on the page (MCID 0), so PDFium's
# per-page view of the tree (FPDF_StructTree_GetForPage) surfaces
# just the Document + P pair — H1 and Figure are filtered out
# because they have no content on this page.

test_that("pdf_structure_tree returns 0 rows for an untagged PDF", {
  for (name in c("shapes", "minimal", "annotated")) {
    out <- pdf_structure_tree(pdf_doc_open(fixture_path(name)), 1L)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
    expect_named(out, c(
      "element_index", "parent_index", "level",
      "type", "parent_type", "obj_type", "title", "lang",
      "alt_text", "actual_text", "id",
      "mcid", "mcid_count", "attributes", "child_mcids"
    ))
  }
})

test_that("pdf_structure_tree walks the tagged-PDF tree", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, page_num = 1L)
  expect_s3_class(res, "tbl_df")
  # PDFium's per-page view only returns elements with content on
  # the page (Document + P). H1 and Figure are filtered out.
  expect_equal(nrow(res), 2L)
  expect_identical(res$element_index, 1L:2L)
  expect_identical(res$type, c("Document", "P"))
  expect_identical(res$parent_index, c(0L, 1L))
  expect_identical(res$level, c(1L, 2L))
  # P has marked content (/MCR with MCID 0); Document does not.
  expect_true(is.na(res$mcid[[1L]]))
  expect_equal(res$mcid[[2L]], 0L)
  expect_equal(res$mcid_count[[1L]], 0L)
  expect_equal(res$mcid_count[[2L]], 1L)
  # parent_type: Document is at the tree root (empty parent type),
  # P's parent is the Document element above it.
  expect_identical(res$parent_type, c("", "Document"))
  # child_mcids: the per-page walk surfaces just Document + P, but
  # the underlying CountChildren still reports the full tree —
  # Document has H1/P/Figure (all nested struct-elements, so all
  # NA), and P has one MCR child (MCID 0).
  expect_type(res$child_mcids, "list")
  expect_length(res$child_mcids, 2L)
  expect_true(all(is.na(res$child_mcids[[1L]])))
  expect_equal(length(res$child_mcids[[1L]]), 3L)
  expect_identical(res$child_mcids[[2L]], 0L)
})

test_that("pdf_structure_tree honours string_attrs", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, page_num = 1L,
                              string_attrs = c("Lang", "Headers"))
  # The fixture's elements have no /A/Lang or /A/Headers attribute
  # objects, so the by-name lookup returns "" for both. The point
  # is that the columns appear with the right types.
  expect_true(all(c("Lang", "Headers") %in% colnames(res)))
  expect_type(res$Lang, "character")
  expect_type(res$Headers, "character")
  expect_length(res$Lang, nrow(res))
  expect_length(res$Headers, nrow(res))
})

test_that("pdf_structure_tree's empty-tibble path includes string_attrs", {
  out <- pdf_structure_tree(pdf_doc_open(fixture_path("minimal")),
                              page_num = 1L,
                              string_attrs = c("Scope"))
  expect_equal(nrow(out), 0L)
  expect_true("Scope" %in% colnames(out))
  expect_type(out$Scope, "character")
})

test_that("pdf_structure_tree validates string_attrs", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # Non-character input is rejected by checkmate.
  expect_error(pdf_structure_tree(doc, string_attrs = 1L),
                 "Assertion on")
  # Empty-string elements are rejected (min.chars = 1L).
  expect_error(pdf_structure_tree(doc, string_attrs = c("Lang", "")),
                 "Assertion on")
  # NA elements are rejected.
  expect_error(pdf_structure_tree(doc, string_attrs = NA_character_),
                 "Assertion on")
})

test_that("pdf_structure_tree accepts a doc + page_num or a page", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_structure_tree(doc, page_num = 1L)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  by_page <- pdf_structure_tree(page)
  expect_identical(by_doc, by_page)
})

test_that("pdf_structure_tree rejects bad inputs and closed pages", {
  expect_error(
    pdf_structure_tree("nope"),
    "class .pdfium_page./.pdfium_doc."
  )
  doc <- pdf_doc_open(fixture_path("tagged"))
  page <- pdf_page_load(doc, 1L)
  pdf_page_close(page)
  expect_error(pdf_structure_tree(page), "closed")
  pdf_doc_close(doc)
})
