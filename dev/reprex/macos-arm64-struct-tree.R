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
#   * Reprex iterating all 43 test files via test_file:     PASSES
#   * R CMD check + TESTTHAT_PARALLEL=true:                 CRASHES
#   * R CMD check + TESTTHAT_PARALLEL=false (no fork):      CRASHES
#   * MallocGuardEdges enabled:                             DID NOT abort
#
# So:
#   - Not a heap OOB write (guard pages didn't catch)
#   - Not fork+GCD (serial testthat reproduces)
#   - Not testthat wrapping (single-file reprex passes)
#   - Not the test files themselves (43-file loop passes)
#
# The differentiator: tests/testthat.R uses testthat::test_check
# (which is package-context-aware), our previous reprex used
# testthat::test_file (which is per-file). test_check's package
# setup must be relevant.
#
# This reprex mirrors tests/testthat.R exactly: load testthat,
# load pdfium, call test_check("pdfium"). Under lldb the
# eventual SIGSEGV is captured with a real C-level backtrace
# pointing at the writer.

cat("== loading testthat + pdfium ==\n"); flush.console()
suppressPackageStartupMessages({
  library(testthat)
  library(pdfium)
})

# R CMD check runs tests from check/pdfium.Rcheck/tests/, which
# has the same testthat.R as the source's tests/testthat.R. Change
# to that directory so test_check finds the testthat/ subdirectory
# relative to the working dir, matching what R CMD check does.
tests_dir <- file.path("check", "pdfium.Rcheck", "tests")
if (!dir.exists(tests_dir)) {
  tests_dir <- file.path("tests")
}
cat("cd to:", tests_dir, "\n")
setwd(tests_dir)
cat("pwd:", getwd(), "\n")
cat("ls:", list.files(), "\n")
flush.console()

# Mirror R CMD check's tests/testthat.R exactly. This is the
# minimum reproducer if the bug is in test_check itself.
testthat::test_check("pdfium")

cat("\n=== REPREX OK (test_check passed; no crash) ===\n")
