#' Path to `tools/download-pdfium.R`, or `""` outside a source tree.
#'
#' `devtools::test()` runs from the source tree; `R CMD check` runs the
#' tests next to the unpacked source under `00_pkg_src/`. An installed
#' package has no `tools/` directory, so callers skip on `""`.
download_pdfium_script <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "tools", "download-pdfium.R"),
    testthat::test_path(
      "..", "..", "00_pkg_src", "pdfium", "tools", "download-pdfium.R"
    )
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0L) "" else normalizePath(hit[[1L]])
}

#' Build a package root holding a vendored, bblanchon-shaped archive.
#'
#' The archive has the layout `tools/download-pdfium.R` expects (headers,
#' a stand-in `libpdfium.so`, the top-level `LICENSE` and `licenses/`),
#' so the script runs offline against it. `notices` names the files
#' written under `licenses/`.
fake_pdfium_pkg <- function(dir, notices = c("pdfium.txt", "zlib.txt")) {
  archive_root <- file.path(dir, "archive")
  dir.create(file.path(archive_root, "include"), recursive = TRUE)
  dir.create(file.path(archive_root, "lib"))
  dir.create(file.path(archive_root, "licenses"))
  writeLines("/* fpdfview.h */", file.path(archive_root, "include", "fpdfview.h"))
  writeBin(as.raw(1:4), file.path(archive_root, "lib", "libpdfium.so"))
  writeLines("MIT: pdfium-binaries build scripts", file.path(archive_root, "LICENSE"))
  for (n in notices) {
    writeLines(paste("notice for", n), file.path(archive_root, "licenses", n))
  }

  pkg <- file.path(dir, "pkg")
  dir.create(file.path(pkg, "tools"), recursive = TRUE)
  dir.create(file.path(pkg, "inst", "pdfium-binaries"), recursive = TRUE)
  writeLines("chromium/0000", file.path(pkg, "tools", "pdfium-version.txt"))
  tgz <- file.path(pkg, "inst", "pdfium-binaries", "pdfium-linux-x64.tgz")
  withr::with_dir(
    archive_root,
    utils::tar(
      tgz,
      files = c("include", "lib", "licenses", "LICENSE"),
      compression = "gzip", tar = "internal"
    )
  )
  pkg
}

#' Run `tools/download-pdfium.R` on `pkg` for linux-x64, offline, with its
#' archive cache inside `cache`. Returns the combined output lines with
#' the exit status in `attr(, "status")` (`NULL` on success).
run_download_pdfium <- function(script, pkg, cache) {
  withr::with_envvar(
    c(PDFIUM_OFFLINE = "1", PDFIUM_CACHE_DIR = cache),
    suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", shQuote(script), shQuote(pkg), "linux-x64"),
      stdout = TRUE, stderr = TRUE
    ))
  )
}
