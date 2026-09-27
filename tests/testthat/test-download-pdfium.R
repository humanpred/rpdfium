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
  archive <- fake_pdfium_archive(file.path(dir, "good.tgz"))
  pkg <- fake_pdfium_pkg(dir, pinned = archive)
  # A notice left by an earlier build must not survive.
  dir.create(file.path(pkg, "inst", "pdfium-licenses"))
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
  archive <- fake_pdfium_archive(file.path(dir, "bad.tgz"), notices = "zlib.txt")
  pkg <- fake_pdfium_pkg(dir, pinned = archive)

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

test_that("download-pdfium.R replaces a truncated cached archive", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  archive <- fake_pdfium_archive(file.path(dir, "good.tgz"))
  pkg <- fake_pdfium_pkg(dir, pinned = archive, vendored = NULL)
  cache <- file.path(dir, "cache")
  dir.create(cache)
  # What an interrupted download used to leave behind.
  cached <- file.path(cache, "0000-pdfium-linux-x64.tgz")
  fake_pdfium_archive(cached, truncate = TRUE)

  out <- run_download_pdfium(script, pkg, cache, url = file_url(archive))

  expect_null(attr(out, "status"))
  expect_match(paste(out, collapse = "\n"), "Discarding cached archive", fixed = TRUE)
  expect_identical(list.files(cache), "0000-pdfium-linux-x64.tgz")
  expect_identical(unname(tools::md5sum(cached)), unname(tools::md5sum(archive)))
  expect_identical(
    readLines(file.path(pkg, "inst", "lib", "libpdfium.so")),
    strrep("a", 4000L)
  )
})

test_that("a download that fails verification leaves nothing in the cache", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  archive <- fake_pdfium_archive(file.path(dir, "good.tgz"))
  truncated <- fake_pdfium_archive(file.path(dir, "cut.tgz"), truncate = TRUE)
  pkg <- fake_pdfium_pkg(dir, pinned = archive, vendored = NULL)
  cache <- file.path(dir, "cache")

  out <- run_download_pdfium(script, pkg, cache, url = file_url(truncated))

  expect_identical(attr(out, "status"), 1L)
  expect_match(paste(out, collapse = "\n"), "is incomplete or not the pinned", fixed = TRUE)
  expect_identical(list.files(cache, all.files = TRUE, no.. = TRUE), character())
  expect_false(dir.exists(file.path(pkg, "inst", "lib")))
})

test_that("a failed download leaves nothing in the cache", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  archive <- fake_pdfium_archive(file.path(dir, "good.tgz"))
  pkg <- fake_pdfium_pkg(dir, pinned = archive, vendored = NULL)
  cache <- file.path(dir, "cache")

  out <- run_download_pdfium(
    script, pkg, cache,
    url = file_url(file.path(dir, "missing.tgz"))
  )

  expect_identical(attr(out, "status"), 1L)
  expect_match(paste(out, collapse = "\n"), "Failed to download PDFium binary", fixed = TRUE)
  expect_identical(list.files(cache, all.files = TRUE, no.. = TRUE), character())
})

test_that("a vendored archive that is not the pinned build is refused", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  skip_if_not(have_sha256(), "needs tools::sha256sum() (R >= 4.5.0)")
  dir <- withr::local_tempdir()
  pinned <- fake_pdfium_archive(file.path(dir, "pinned.tgz"), flavour = "a")
  other <- fake_pdfium_archive(file.path(dir, "other.tgz"), flavour = "b")
  pkg <- fake_pdfium_pkg(dir, pinned = pinned, vendored = other)

  out <- run_download_pdfium(script, pkg, file.path(dir, "cache"))

  expect_identical(attr(out, "status"), 1L)
  expect_match(
    paste(out, collapse = "\n"),
    "The vendored archive .* is incomplete or not the pinned pdfium-linux-x64.tgz for chromium/0000"
  )
  expect_false(dir.exists(file.path(pkg, "inst", "lib")))
})

test_that("checksums recorded for another release stop the install", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  archive <- fake_pdfium_archive(file.path(dir, "good.tgz"))
  pkg <- fake_pdfium_pkg(dir, pinned = archive, checksum_release = "chromium/9999")

  out <- run_download_pdfium(script, pkg, file.path(dir, "cache"))

  expect_identical(attr(out, "status"), 1L)
  expect_match(
    paste(out, collapse = "\n"),
    "is for chromium/9999 but tools/pdfium-version.txt pins chromium/0000",
    fixed = TRUE
  )
})

test_that("an archive with no pinned checksum stops the install", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  archive <- fake_pdfium_archive(file.path(dir, "good.tgz"))
  pkg <- fake_pdfium_pkg(dir, pinned = archive, checksum_archive = "pdfium-mac-arm64.tgz")

  out <- run_download_pdfium(script, pkg, file.path(dir, "cache"))

  expect_identical(attr(out, "status"), 1L)
  expect_match(
    paste(out, collapse = "\n"),
    "pins no archive named pdfium-linux-x64.tgz",
    fixed = TRUE
  )
})

test_that("a malformed checksums file stops the install", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  dir <- withr::local_tempdir()
  archive <- fake_pdfium_archive(file.path(dir, "good.tgz"))
  pkg <- fake_pdfium_pkg(dir, pinned = archive)
  sums <- file.path(pkg, "tools", "pdfium-checksums.txt")
  lines <- readLines(sums)

  writeLines(c(lines, "abc123  pdfium-mac-arm64.tgz"), sums)
  out <- run_download_pdfium(script, pkg, file.path(dir, "cache"))
  expect_identical(attr(out, "status"), 1L)
  expect_match(
    paste(out, collapse = "\n"),
    "Malformed line in tools/pdfium-checksums.txt: abc123  pdfium-mac-arm64.tgz",
    fixed = TRUE
  )

  writeLines(c(lines, lines[[2L]]), sums)
  out <- run_download_pdfium(script, pkg, file.path(dir, "cache"))
  expect_identical(attr(out, "status"), 1L)
  expect_match(
    paste(out, collapse = "\n"),
    "lists pdfium-linux-x64.tgz more than once",
    fixed = TRUE
  )
})

test_that("tools/pdfium-checksums.txt pins every archive for the pinned release", {
  script <- download_pdfium_script()
  skip_if(!nzchar(script), "tools/download-pdfium.R is only in a source tree")
  tools_dir <- dirname(script)
  lines <- readLines(file.path(tools_dir, "pdfium-checksums.txt"))
  lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
  release <- readLines(file.path(tools_dir, "pdfium-version.txt"))[[1L]]

  expect_identical(lines[[1L]], paste("release:", release))
  fields <- strsplit(lines[-1L], "  ", fixed = TRUE)
  expect_true(all(lengths(fields) == 2L))
  sums <- vapply(fields, `[`, character(1L), 1L)
  archives <- vapply(fields, `[`, character(1L), 2L)
  # Every platform tag detect_platform() can return (bblanchon has no
  # mac-x86 build).
  expect_setequal(
    archives,
    sprintf("pdfium-%s.tgz", c(
      "linux-x64", "linux-arm64", "linux-x86",
      "linux-musl-x64", "linux-musl-arm64", "linux-musl-x86",
      "mac-x64", "mac-arm64",
      "win-x64", "win-arm64", "win-x86"
    ))
  )
  expect_true(all(grepl("^[0-9a-f]{64}$", sums)))
  expect_false(anyDuplicated(archives) > 0L)
})
