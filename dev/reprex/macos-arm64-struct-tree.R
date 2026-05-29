# Minimal reprex for the macOS arm64 segfault in
# cpp_struct_tree_page (humanpred/rpdfium#44).
#
# Symptom on macos-latest (R 4.6.0 arm64):
#   *** caught segfault ***
#   address 0x656e6e75722f7372 (= ASCII "rs/runne"),
#   cause 'invalid permissions'
#   Traceback:
#    1: cpp_struct_tree_page(page$ptr, string_attrs)
#
# Status (from successive CI runs on this PR):
#   * Standalone Rscript (no testthat): runs ALL 4 tests cleanly
#   * R CMD check + testthat parallel=true:  CRASHES at test 4
#   * R CMD check + testthat parallel=false: CRASHES at test 4
#   * MallocGuardEdges enabled: DID NOT abort
#
# So the corruption is NOT a heap OOB write (guard pages would
# have caught it). And it is NOT a fork-after-GCD issue (serial
# testthat reproduces it). The differentiator is testthat itself.
#
# This reprex wraps the test sequence in testthat::test_that()
# blocks so it executes the same code path as test_check, but in
# a single R process under lldb. If it crashes here, lldb captures
# the stack at the SIGSEGV moment.

cat("== loading testthat + pdfium ==\n"); flush.console()
suppressPackageStartupMessages({
  library(testthat)
  library(pdfium)
})

fixture_path <- function(name) {
  p <- system.file("extdata", "fixtures", paste0(name, ".pdf"),
                   package = "pdfium")
  stopifnot(nzchar(p))
  normalizePath(p, winslash = "/", mustWork = TRUE)
}

cat("\n=================================================\n")
cat("Mirror of tests/testthat/test-struct-tree.R\n")
cat("=================================================\n")

test_that("pdf_structure_tree returns 0 rows for an untagged PDF", {
  for (name in c("shapes", "minimal", "annotated")) {
    out <- pdf_structure_tree(pdf_doc_open(fixture_path(name)), 1L)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
  }
})

test_that("pdf_structure_tree walks the tagged-PDF tree", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, page_num = 1L)
  expect_equal(nrow(res), 2L)
  expect_identical(res$type, c("Document", "P"))
})

test_that("pdf_structure_tree surfaces typed /A attribute values", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, 1L)
  attrs <- res$attributes[[2L]]
  expect_setequal(
    names(attrs),
    c("O", "Placement", "SpaceBefore", "BBox", "BorderStyle", "Hidden")
  )
})

# CRASH SITE (in R CMD check): test 4 first calls into
# Rcpp::as<vector<string>> from pdfium.so. The static `fun`
# pointer in pdfium.so's char_get_string_elt initializes here.
# R_GetCCallable then hits the corrupted CEntryTable.
test_that("pdf_structure_tree honours string_attrs", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(
    doc,
    page_num = 1L,
    string_attrs = c("Placement", "O", "Headers")
  )
  expect_true(all(c("Placement", "O", "Headers") %in% colnames(res)))
  expect_identical(res$Placement[[2L]], "Block")
  expect_identical(res$O[[2L]], "Layout")
  expect_identical(res$Headers[[2L]], "")
})

cat("\n=== REPREX OK (testthat-wrapped tests passed; no crash) ===\n")
