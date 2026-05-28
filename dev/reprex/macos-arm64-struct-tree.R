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
# Apple-pre-symbolicated `.ips` shows the C frames:
#   #4  get_package_CEntry_table  R/src/main/Rdynload.c:1738
#   #5  R_GetCCallable            Rdynload.c:1760
#   #6  char_get_string_elt       Rcpp routines.h:218 (inline)
#   #7  Rcpp::internal::as_string_elt__impl<std::string>
#   #11 _pdfium_cpp_struct_tree_page  RcppExports.cpp:3103
#
# Confirms: the fault is at R's static `CEntryTable` SEXP being
# corrupted to ASCII bytes. The corruption is from an earlier
# operation in the same testthat subprocess. This reprex mirrors
# the test sequence in tests/testthat/test-struct-tree.R so the
# wild write happens while a debugger (or hardened allocator) is
# attached.
#
# Used by .github/workflows/R-CMD-check.yaml's "Run struct-tree
# reprex under lldb" step. R_LIBS_USER must point at the
# pdfium.Rcheck directory so library(pdfium) resolves.

cat("== loading pdfium ==\n"); flush.console()
suppressPackageStartupMessages(library(pdfium))

fixture_dir <- system.file("extdata", "fixtures", package = "pdfium")
stopifnot(nzchar(fixture_dir))
fixture <- function(n) file.path(fixture_dir, paste0(n, ".pdf"))

# Mirror test-struct-tree.R run order so the wild write happens
# inside this script's process. Each block matches one test_that()
# in the test file.

cat("\n== test 1: pdf_structure_tree on untagged PDFs ==\n")
for (n in c("shapes", "minimal", "annotated")) {
  cat("  ", n, "\n"); flush.console()
  out <- pdf_structure_tree(pdf_doc_open(fixture(n)), 1L)
  stopifnot(nrow(out) == 0L)
}

cat("\n== test 2: pdf_structure_tree walks the tagged-PDF tree ==\n")
doc <- pdf_doc_open(fixture("tagged"))
res <- pdf_structure_tree(doc, page_num = 1L)
cat("  rows:", nrow(res), "\n"); flush.console()

cat("\n== test 3: typed /A attribute values ==\n")
res <- pdf_structure_tree(doc, 1L)
attrs <- res$attributes[[2L]]
cat("  attribute names:", paste(names(attrs), collapse = ", "), "\n")
flush.console()

cat("\n== test 4: honours string_attrs (CRASH SITE) ==\n")
res <- pdf_structure_tree(
  doc,
  page_num = 1L,
  string_attrs = c("Placement", "O", "Headers")
)
cat("  Placement[2]:", res$Placement[[2L]], "\n")
cat("  O[2]:", res$O[[2L]], "\n")
cat("  Headers[2]:", res$Headers[[2L]], "\n")

cat("\n== cleanup ==\n")
pdf_doc_close(doc)
gc()

cat("\nREPREX OK (all tests passed; no crash)\n")
