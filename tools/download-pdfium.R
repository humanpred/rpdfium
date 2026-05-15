# Download and extract the pinned bblanchon/pdfium-binaries release.
#
# Called by `configure` (POSIX) and `configure.win` (Windows) at install time.
# Outputs:
#   - inst/include/    headers from the bblanchon archive
#   - inst/lib/        libpdfium.{so,dylib} (POSIX) or pdfium.lib (Windows)
#   - inst/bin/        pdfium.dll (Windows only)
#
# Honors:
#   - PDFIUM_OFFLINE        if set to "1", skip downloading and require
#                           that inst/pdfium-binaries/<archive> already
#                           exists locally (offline / CRAN-builder use).
#   - PDFIUM_BINARY_URL     override the URL (e.g. for mirrors).
#   - PDFIUM_CACHE_DIR      directory to cache downloaded archives across
#                           rebuilds. Defaults to tools::R_user_dir("pdfium",
#                           "cache") when available.

local({
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1L) {
    stop("usage: Rscript tools/download-pdfium.R <package-root> [platform-tag]")
  }
  pkg_root <- normalizePath(args[[1L]], mustWork = TRUE)
  platform_tag <- if (length(args) >= 2L && nzchar(args[[2L]])) args[[2L]] else NULL

  version_file <- file.path(pkg_root, "tools", "pdfium-version.txt")
  if (!file.exists(version_file)) {
    stop("Missing tools/pdfium-version.txt at ", version_file)
  }
  release_tag <- trimws(readLines(version_file, warn = FALSE)[[1L]])
  if (!nzchar(release_tag)) stop("tools/pdfium-version.txt is empty.")

  detect_platform <- function() {
    sysname <- tolower(Sys.info()[["sysname"]])
    machine <- tolower(Sys.info()[["machine"]])
    arch <- switch(
      machine,
      "x86_64" = "x64", "amd64" = "x64",
      "arm64" = "arm64", "aarch64" = "arm64",
      "i686" = "x86", "i386" = "x86",
      stop("Unsupported architecture: ", machine)
    )
    is_musl <- function() {
      out <- suppressWarnings(system2("ldd", "--version", stdout = TRUE, stderr = TRUE))
      any(grepl("musl", out, ignore.case = TRUE))
    }
    if (sysname == "darwin")  return(paste0("mac-", arch))
    if (sysname == "linux")   return(paste0(if (is_musl()) "linux-musl-" else "linux-", arch))
    if (sysname == "windows") return(paste0("win-", arch))
    stop("Unsupported OS: ", sysname)
  }

  platform <- if (is.null(platform_tag)) detect_platform() else platform_tag
  archive_name <- sprintf("pdfium-%s.tgz", platform)
  base_url <- "https://github.com/bblanchon/pdfium-binaries/releases/download"
  url <- Sys.getenv("PDFIUM_BINARY_URL",
                    sprintf("%s/%s/%s", base_url, release_tag, archive_name))

  cache_dir <- Sys.getenv("PDFIUM_CACHE_DIR", "")
  if (!nzchar(cache_dir)) {
    cache_dir <- tryCatch(
      tools::R_user_dir("pdfium", "cache"),
      error = function(e) tempfile("pdfium-cache-")
    )
  }
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  cache_path <- file.path(cache_dir, sprintf("%s-%s", basename(release_tag), archive_name))
  offline <- isTRUE(Sys.getenv("PDFIUM_OFFLINE") == "1")

  vendored <- file.path(pkg_root, "inst", "pdfium-binaries", archive_name)
  if (file.exists(vendored)) {
    message("[pdfium] Using vendored archive: ", vendored)
    cache_path <- vendored
  } else if (offline) {
    stop("PDFIUM_OFFLINE=1 set but vendored archive not found at ", vendored)
  } else if (!file.exists(cache_path)) {
    message("[pdfium] Downloading ", url)
    tryCatch(
      utils::download.file(url, cache_path, mode = "wb", quiet = TRUE),
      error = function(e) stop(
        "Failed to download PDFium binary from ", url,
        ". Set PDFIUM_OFFLINE=1 and place the archive at inst/pdfium-binaries/",
        archive_name, " to install without network access. Original error: ",
        conditionMessage(e), call. = FALSE
      )
    )
  } else {
    message("[pdfium] Using cached archive: ", cache_path)
  }

  extract_root <- file.path(pkg_root, "inst")
  staging <- tempfile("pdfium-extract-")
  dir.create(staging, recursive = TRUE)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  utils::untar(cache_path, exdir = staging)

  copy_into <- function(subdir, target_subdir = subdir) {
    src <- file.path(staging, subdir)
    if (!dir.exists(src)) return(invisible())
    dst <- file.path(extract_root, target_subdir)
    dir.create(dst, recursive = TRUE, showWarnings = FALSE)
    files <- list.files(src, recursive = TRUE, full.names = TRUE, all.files = FALSE)
    for (f in files) {
      rel <- substring(f, nchar(src) + 2L)
      to <- file.path(dst, rel)
      dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
      file.copy(f, to, overwrite = TRUE, copy.date = TRUE)
    }
  }
  copy_into("include")
  copy_into("lib")
  copy_into("bin")

  cat(file.path(extract_root, "include"), "\n",
      file.path(extract_root, "lib"),     "\n",
      sep = "")
})
