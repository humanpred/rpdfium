# tests/testthat/setup.R
#
# Sourced once per parallel testthat worker before the worker's first test
# file runs. Keep this fast and side-effect-free aside from configuring the
# session — heavy fixtures live in helper-fixtures.R, loaded lazily.
#
# Reminder for AI contributors: when Config/testthat/parallel: true is set
# in DESCRIPTION, every test file runs in a fresh subprocess. Never share
# mutable state between test files; do per-test setup with withr::defer().

options(pdfium.tests.run = TRUE)

withr::local_options(
  list(
    warnPartialMatchArgs = TRUE,
    warnPartialMatchDollar = TRUE,
    warnPartialMatchAttr = TRUE
  ),
  .local_envir = testthat::teardown_env()
)
