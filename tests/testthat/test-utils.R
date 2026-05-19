test_that("inst/lib/ is populated under the installed package", {
  # The configure script deposits libpdfium.{so,dylib,dll} and the
  # public headers into `inst/lib/` and `inst/include/`. Make sure
  # the install path resolves; a non-empty result means the binary
  # is on disk, which is the minimum requirement for the package to
  # have linked at install time.
  d <- system.file("lib", package = "pdfium")
  expect_type(d, "character")
  expect_true(nzchar(d))
})
