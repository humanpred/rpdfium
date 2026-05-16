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
    # Different OSes report 64-bit Intel in different ways:
    #   linux/macOS   -> "x86_64"
    #   Windows       -> "x86-64" (with hyphen) on recent R
    #   some toolchains -> "amd64"
    arch <- switch(
      machine,
      "x86_64" = "x64", "x86-64" = "x64", "amd64" = "x64",
      "arm64" = "arm64", "aarch64" = "arm64",
      "i686" = "x86", "i386" = "x86", "x86" = "x86",
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

  # bblanchon's macOS libpdfium.dylib ships with LC_ID_DYLIB set to
  # `./libpdfium.dylib`, which makes the dynamic loader look in the CWD
  # rather than at the RPATH we embed in pdfium.so. Rewrite the install
  # name to @rpath/libpdfium.dylib so dlopen() resolves it through the
  # RPATH set by configure.
  fix_macos_install_name <- function(libdir) {
    if (tolower(Sys.info()[["sysname"]]) != "darwin") return(invisible())
    dylib <- file.path(libdir, "libpdfium.dylib")
    if (!file.exists(dylib)) return(invisible())
    if (Sys.which("install_name_tool") == "") {
      warning("install_name_tool not found; cannot rewrite libpdfium.dylib install name. ",
              "Loading may fail at runtime.", call. = FALSE)
      return(invisible())
    }
    res <- system2("install_name_tool",
                   c("-id", "@rpath/libpdfium.dylib", shQuote(dylib)),
                   stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(res, "status")) && attr(res, "status") != 0L) {
      warning("install_name_tool -id failed: ", paste(res, collapse = "\n"),
              call. = FALSE)
    } else {
      message("[pdfium] Rewrote libpdfium.dylib install name to @rpath/libpdfium.dylib")
    }
  }

  # bblanchon's Windows tarball ships:
  #   - bin/pdfium.dll       (the runtime DLL)
  #   - lib/pdfium.dll.lib   (MSVC-style import lib; unused — see below)
  #
  # Our R package is named `pdfium`, so R builds its own `pdfium.dll`
  # into <pkg>/libs/<arch>/. If we placed bblanchon's `pdfium.dll`
  # in the same directory it would collide with our package's DLL on
  # disk, and Windows can't load two DLLs with the same name from
  # the same process anyway. We rename bblanchon's DLL to
  # `libpdfium.dll` (kept in inst/bin/ until src/install.libs.R
  # relocates it to <pkg>/libs/<arch>/).
  #
  # bblanchon's `pdfium.dll.lib` is in MSVC import-library format and
  # references the original DLL filename internally, so it can't be
  # reused after the rename. Rather than regenerate a Mingw `.dll.a`
  # (which requires `gendef`, not shipped with Rtools 4.5),
  # src/Makevars.win links against `libpdfium.dll` directly via GNU
  # ld's `-l:filename` syntax — ld reads the DLL's export table to
  # build the import table at link time, so no separate import
  # library is needed. We drop the stale `.dll.lib` to keep the
  # installed package tidy.
  fix_windows_dll <- function(extract_root) {
    if (tolower(Sys.info()[["sysname"]]) != "windows") return(invisible())

    src_dll <- file.path(extract_root, "bin", "pdfium.dll")
    src_lib <- file.path(extract_root, "lib", "pdfium.dll.lib")
    if (!file.exists(src_dll)) {
      warning("Expected bblanchon pdfium.dll not found at ", src_dll,
              "; Windows install will likely fail.", call. = FALSE)
      return(invisible())
    }

    # Rename pdfium.dll -> libpdfium.dll. Kept in inst/bin/ until
    # src/install.libs.R relocates it to <pkg>/libs/<arch>/.
    dst_dll <- file.path(extract_root, "bin", "libpdfium.dll")
    if (!file.copy(src_dll, dst_dll, overwrite = TRUE)) {
      stop("Failed to rename pdfium.dll to libpdfium.dll", call. = FALSE)
    }
    file.remove(src_dll)

    # Drop bblanchon's MSVC import library — Makevars.win links the
    # DLL directly so we don't ship it.
    if (file.exists(src_lib)) file.remove(src_lib)

    message("[pdfium] Renamed pdfium.dll -> libpdfium.dll ",
            "(Makevars.win links against the DLL directly).")
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

  fix_macos_install_name(file.path(extract_root, "lib"))
  fix_windows_dll(extract_root)

  cat(file.path(extract_root, "include"), "\n",
      file.path(extract_root, "lib"),     "\n",
      sep = "")
})
