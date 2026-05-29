# Minimal reprex for the macOS arm64 segfault in
# cpp_struct_tree_page (humanpred/rpdfium#44).
#
# Symptom on macos-latest (R 4.6.0 arm64):
#   *** caught segfault ***
#   address 0x656e6e75722f7372 (= ASCII "rs/runne"),
#   cause 'invalid permissions'
#   Traceback:  1: cpp_struct_tree_page(page$ptr, string_attrs)
#
# Status (from successive CI runs on this PR):
#   * Standalone Rscript reprex (no testthat):              PASSES
#   * Standalone reprex with testthat::test_that blocks:    PASSES
#   * R CMD check + TESTTHAT_PARALLEL=true:                 CRASHES
#   * R CMD check + TESTTHAT_PARALLEL=false (no fork):      CRASHES
#   * MallocGuardEdges enabled:                             DID NOT abort
#
# So:
#   - The bug is NOT a heap OOB write (guard pages didn't catch)
#   - The bug is NOT a fork-after-GCD issue (serial testthat
#     reproduces it)
#   - The bug is NOT testthat's wrapping itself (single-file
#     testthat reprex passes)
#
# The remaining differentiator: R CMD check runs ALL test files
# in alphabetical order before test-struct-tree.R via
# testthat::test_check. Some EARLIER test file's C++ work
# corrupts R's static CEntryTable. When test-struct-tree.R's
# "honours string_attrs" test then triggers Rcpp's first call to
# char_get_string_elt from pdfium.so, R_GetCCallable hits the
# trampled slot and SIGSEGVs.
#
# This reprex runs every test file up to and including
# test-struct-tree.R in sequence via testthat::test_file in a
# single R process under lldb. When the corrupting file's
# operations trigger the bad write, lldb catches the SIGSEGV.
# The faulting frame in `bt all` is the writer.

cat("== loading testthat + pdfium ==\n"); flush.console()
suppressPackageStartupMessages({
  library(testthat)
  library(pdfium)
})

# After R CMD check, the testthat directory is at
# check/pdfium.Rcheck/00_pkg_src/pdfium/tests/testthat (source
# extracted by `R CMD check`). Helpers + test-*.R files live there.
candidates <- c(
  file.path("check", "pdfium.Rcheck", "00_pkg_src", "pdfium",
            "tests", "testthat"),
  file.path("check", "pdfium.Rcheck", "tests", "testthat"),
  file.path("tests", "testthat")
)
test_dir <- NULL
for (cand in candidates) {
  if (dir.exists(cand)) { test_dir <- cand; break }
}
stopifnot(!is.null(test_dir))
cat("testthat dir:", test_dir, "\n"); flush.console()

# Source helpers first (test_file does NOT auto-load helpers on
# a standalone call).
for (h in list.files(test_dir, pattern = "^helper-",
                      full.names = TRUE)) {
  cat("  sourcing helper:", basename(h), "\n")
  source(h, local = .GlobalEnv)
}

# Find all test-*.R files in alphabetical order, up to and
# including test-struct-tree.R. (Past struct-tree we don't need.)
all_tests <- sort(list.files(test_dir, pattern = "^test-.*\\.R$",
                              full.names = TRUE))
keep_through <- which(grepl("struct-tree", basename(all_tests)))[[1L]]
tests_to_run <- all_tests[seq_len(keep_through)]
cat("running", length(tests_to_run), "test files in order:\n")
cat(paste0("  ", basename(tests_to_run)), sep = "\n")

# Run each via test_file. The first one to corrupt CEntryTable
# triggers the SIGSEGV under lldb when test-struct-tree.R's
# "honours string_attrs" test runs.
for (tf in tests_to_run) {
  cat("\n>>> ", basename(tf), "\n"); flush.console()
  testthat::test_file(tf, reporter = "summary", stop_on_failure = FALSE)
}

cat("\n=== REPREX OK (all test files ran; no crash) ===\n")
