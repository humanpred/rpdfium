#' Path to `tools/download-pdfium.R`, or `""` outside a source tree
#' (`source_tree_path()`).
download_pdfium_script <- function() {
  source_tree_path("tools", "download-pdfium.R") # nolint: object_usage_linter.
}

#' Whether this R can compute SHA-256 (`tools::sha256sum()`, R >= 4.5.0).
have_sha256 <- function() {
  exists("sha256sum", envir = asNamespace("tools"))
}

#' Write a bblanchon-shaped archive to `path` and return `path`.
#'
#' The archive has the layout `tools/download-pdfium.R` expects: headers,
#' a stand-in `libpdfium.so`, the top-level `LICENSE`, and `licenses/`
#' holding `notices`. `flavour` goes into the stand-in library so two
#' archives can differ. `truncate` keeps only the first half of the bytes,
#' as an interrupted download would.
fake_pdfium_archive <- function(path, notices = c("pdfium.txt", "zlib.txt"),
                                flavour = "a", truncate = FALSE) {
  root <- tempfile("fake-pdfium-")
  dir.create(file.path(root, "include"), recursive = TRUE)
  dir.create(file.path(root, "lib"))
  dir.create(file.path(root, "licenses"))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("/* fpdfview.h */", file.path(root, "include", "fpdfview.h"))
  writeLines(strrep(flavour, 4000L), file.path(root, "lib", "libpdfium.so"))
  writeLines("MIT: pdfium-binaries build scripts", file.path(root, "LICENSE"))
  for (n in notices) {
    writeLines(paste("notice for", n), file.path(root, "licenses", n))
  }
  path <- file.path(normalizePath(dirname(path)), basename(path))
  withr::with_dir(
    root,
    utils::tar(
      path,
      files = c("include", "lib", "licenses", "LICENSE"),
      compression = "gzip", tar = "internal"
    )
  )
  if (truncate) {
    bytes <- readBin(path, "raw", n = file.size(path))
    writeBin(bytes[seq_len(length(bytes) %/% 2L)], path)
  }
  path
}

#' Build a package root for `tools/download-pdfium.R` to work on.
#'
#' It pins `chromium/0000` and records in `tools/pdfium-checksums.txt` the
#' SHA-256 of `pinned` under the name `pdfium-linux-x64.tgz`, with the
#' checksum file's release set to `checksum_release`. When `vendored` is
#' not `NULL`, that archive is staged as the vendored
#' `inst/pdfium-binaries/pdfium-linux-x64.tgz`.
fake_pdfium_pkg <- function(dir, pinned, vendored = pinned,
                            checksum_release = "chromium/0000",
                            checksum_archive = "pdfium-linux-x64.tgz") {
  pkg <- file.path(dir, "pkg")
  dir.create(file.path(pkg, "tools"), recursive = TRUE)
  dir.create(file.path(pkg, "inst"))
  writeLines("chromium/0000", file.path(pkg, "tools", "pdfium-version.txt"))
  sha <- if (have_sha256()) unname(tools::sha256sum(pinned)) else strrep("0", 64L)
  writeLines(
    c(
      paste("release:", checksum_release),
      paste0(sha, "  ", checksum_archive)
    ),
    file.path(pkg, "tools", "pdfium-checksums.txt")
  )
  if (!is.null(vendored)) {
    dir.create(file.path(pkg, "inst", "pdfium-binaries"))
    file.copy(
      vendored,
      file.path(pkg, "inst", "pdfium-binaries", "pdfium-linux-x64.tgz")
    )
  }
  pkg
}

#' A `file://` URL for a local file, in the form `download.file()` accepts.
file_url <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  paste0("file://", if (startsWith(path, "/")) "" else "/", path)
}

#' Run `tools/download-pdfium.R` on `pkg` for linux-x64 with its archive
#' cache in `cache`. With `url = NULL` it runs offline (vendored archive
#' only); otherwise it downloads from `url`. Returns the combined output
#' lines with the exit status in `attr(, "status")` (`NULL` on success).
run_download_pdfium <- function(script, pkg, cache, url = NULL) {
  env <- if (is.null(url)) {
    c(PDFIUM_OFFLINE = "1", PDFIUM_CACHE_DIR = cache, PDFIUM_BINARY_URL = NA)
  } else {
    c(PDFIUM_OFFLINE = NA, PDFIUM_CACHE_DIR = cache, PDFIUM_BINARY_URL = url)
  }
  withr::with_envvar(
    env,
    suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", shQuote(script), shQuote(pkg), "linux-x64"),
      stdout = TRUE, stderr = TRUE
    ))
  )
}
