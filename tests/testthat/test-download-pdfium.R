test_that("a bundled libpdfium ships with PDFium's licence notices", {
  # configure's download path bundles libpdfium into the installed
  # package, and binary packages built from it redistribute PDFium, so
  # the notices have to be installed too. A system libpdfium (pkg-config
  # or a system prefix) is not bundled; PDFIUM_HOME is the user's own
  # install and brings its own terms.
  skip_if(nzchar(Sys.getenv("PDFIUM_HOME")), "PDFIUM_HOME supplies libpdfium")
  bundled <- nzchar(c(
    system.file("lib", "libpdfium.so", package = "pdfium"),
    system.file("lib", "libpdfium.dylib", package = "pdfium"),
    system.file("bin", "libpdfium.dll", package = "pdfium")
  ))
  skip_if_not(any(bundled), "libpdfium comes from a system install")

  notices <- system.file("pdfium-licenses", package = "pdfium")
  expect_true(nzchar(notices))
  pdfium_txt <- file.path(notices, "pdfium.txt")
  expect_true(file.exists(pdfium_txt))
  expect_match(
    paste(readLines(pdfium_txt, warn = FALSE), collapse = " "),
    "Redistribution and use in source and binary forms",
    fixed = TRUE
  )
  expect_match(
    paste(readLines(file.path(notices, "LICENSE"), warn = FALSE), collapse = " "),
    "Benoit Blanchon",
    fixed = TRUE
  )
})

test_that("download-pdfium.R installs exactly the archive's licence notices", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  pkg <- fake_pdfium_pkg(dir, notices = c("pdfium.txt", "zlib.txt"))
  # A notice left by an earlier build must not survive.
  dir.create(file.path(pkg, "inst", "pdfium-licenses"), recursive = TRUE)
  writeLines("stale", file.path(pkg, "inst", "pdfium-licenses", "stale.txt"))

  out <- run_download_pdfium(script, pkg, file.path(dir, "cache"))

  expect_null(attr(out, "status"))
  installed <- file.path(pkg, "inst", "pdfium-licenses")
  expect_identical(
    sort(list.files(installed)),
    c("LICENSE", "pdfium.txt", "zlib.txt")
  )
  expect_identical(
    readLines(file.path(installed, "pdfium.txt")),
    "notice for pdfium.txt"
  )
  expect_identical(
    readLines(file.path(installed, "zlib.txt")),
    "notice for zlib.txt"
  )
  expect_identical(
    readLines(file.path(installed, "LICENSE")),
    "MIT: pdfium-binaries build scripts"
  )
  expect_true(file.exists(file.path(pkg, "inst", "lib", "libpdfium.so")))
})

test_that("download-pdfium.R refuses an archive without PDFium's notice", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  pkg <- fake_pdfium_pkg(dir, notices = "zlib.txt")

  out <- run_download_pdfium(script, pkg, file.path(dir, "cache"))

  expect_identical(attr(out, "status"), 1L)
  expect_match(
    paste(out, collapse = "\n"),
    "has no licenses/pdfium.txt",
    fixed = TRUE
  )
  # Nothing is installed from an archive that is refused.
  expect_false(dir.exists(file.path(pkg, "inst", "lib")))
  expect_false(dir.exists(file.path(pkg, "inst", "pdfium-licenses")))
})
