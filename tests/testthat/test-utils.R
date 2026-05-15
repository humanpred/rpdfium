test_that("pdfium_lib_dir() returns an existing path under the installed pkg", {
  d <- pdfium:::pdfium_lib_dir()
  expect_type(d, "character")
})
