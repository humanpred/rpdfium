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
  #   - lib/pdfium.dll.lib   (MSVC-style import lib)
  #
  # Two problems compound on Windows:
  #
  #   1. Our R package is also named `pdfium`, so R builds its own
  #      `pdfium.dll` into <pkg>/libs/<arch>/. Bblanchon's DLL would
  #      collide on disk and Windows cannot load two DLLs with the
  #      same name in the same process anyway.
  #   2. bblanchon's `pdfium.dll.lib` is in MSVC format and references
  #      the original DLL filename internally — unusable from Mingw
  #      ld, and unusable after we rename the DLL.
  #
  # So we rename the DLL to `libpdfium.dll` and regenerate a Mingw
  # import library (`libpdfium.dll.a`) whose `LIBRARY` directive
  # bakes in the new name. Critical: a direct `ld -l:libpdfium.dll`
  # link does NOT work, because ld picks up the DLL's *internal*
  # "Module Name" field (still `pdfium.dll` from how bblanchon built
  # it) when generating the import table — producing a package DLL
  # that asks Windows for `pdfium.dll` at runtime and loops back on
  # itself.
  #
  # Generating the import library needs the export name list:
  #   - `gendef` is the usual MSYS2 tool, but ships only with
  #     `mingw-w64-tools` — not Rtools 4.5.
  #   - `objdump -p` output format varies across binutils versions
  #     and Rtools 4.5's build does not print the
  #     `[Ordinal/Name Pointer] Table` block we'd otherwise scrape.
  # So we parse the PE export directory directly from the bytes of
  # the DLL using `readBin()`. The format is stable (Microsoft PE/COFF
  # spec) and needs no external tool. `dlltool` (binutils, in Rtools)
  # then assembles the `.dll.a` from the `.def` we write.

  # Parse export-table function names from a PE/COFF DLL.
  # Returns a character vector of named exports (ordinal-only exports
  # without a name are skipped). Implements the minimum slice of
  # Microsoft PE/COFF needed to walk the AddressOfNames array of the
  # export directory; no external tooling involved.
  parse_pe_exports <- function(dll_path) {
    con <- file(dll_path, "rb")
    on.exit(close(con))
    read_u16 <- function() {
      readBin(con, integer(), n = 1L, size = 2L,
              signed = FALSE, endian = "little")
    }
    read_u32 <- function() {
      # `readBin` ignores `signed` for size 4, so for values that
      # might exceed INT_MAX we'd need to compose by bytes. PE RVAs
      # are bounded by the 4GB image size so signed interpretation
      # is safe in practice for everything we need here.
      readBin(con, integer(), n = 1L, size = 4L, endian = "little")
    }

    seek(con, 0x3c)
    pe_offset <- read_u32()
    seek(con, pe_offset)
    sig <- readBin(con, raw(), n = 4L)
    if (!identical(sig[1L:2L], charToRaw("PE")) ||
        sig[3L] != as.raw(0L) || sig[4L] != as.raw(0L)) {
      stop("Not a PE file: ", dll_path, call. = FALSE)
    }
    # COFF header: machine(2) num_sections(2) timestamp(4)
    # ptrsymtab(4) numsyms(4) size_opt_header(2) characteristics(2).
    seek(con, pe_offset + 4L + 2L)
    num_sections <- read_u16()
    seek(con, pe_offset + 4L + 16L)
    size_opt_header <- read_u16()
    read_u16()  # characteristics

    opt_header_offset <- pe_offset + 4L + 20L
    seek(con, opt_header_offset)
    magic <- read_u16()  # 0x10b = PE32, 0x20b = PE32+
    is_pe32_plus <- magic == 0x20bL
    data_dir_offset <- opt_header_offset +
      if (is_pe32_plus) 112L else 96L

    seek(con, data_dir_offset)
    export_rva <- read_u32()
    read_u32()  # export size
    if (export_rva == 0L) {
      stop("DLL has no export directory: ", dll_path, call. = FALSE)
    }

    # Section table immediately follows the optional header.
    section_table_offset <- opt_header_offset + size_opt_header
    sections <- vector("list", num_sections)
    for (i in seq_len(num_sections)) {
      seek(con, section_table_offset + (i - 1L) * 40L)
      readBin(con, raw(), n = 8L)  # section name
      virtual_size <- read_u32()
      virtual_addr <- read_u32()
      raw_size <- read_u32()
      raw_ptr <- read_u32()
      sections[[i]] <- list(vaddr = virtual_addr,
                            vsize = max(virtual_size, raw_size),
                            raddr = raw_ptr)
    }
    rva_to_offset <- function(rva) {
      for (s in sections) {
        if (rva >= s$vaddr && rva < s$vaddr + s$vsize) {
          return(s$raddr + (rva - s$vaddr))
        }
      }
      stop(sprintf("RVA 0x%x not in any PE section", rva),
           call. = FALSE)
    }

    # IMAGE_EXPORT_DIRECTORY:
    #   Characteristics(4), TimeDateStamp(4), Major(2), Minor(2),
    #   Name(4), Base(4), NumFuncs(4), NumNames(4),
    #   AddressOfFunctions(4), AddressOfNames(4),
    #   AddressOfNameOrdinals(4).
    seek(con, rva_to_offset(export_rva))
    read_u32(); read_u32(); read_u16(); read_u16()
    read_u32(); read_u32()              # Name (rva), Base
    read_u32()                          # NumberOfFunctions
    num_names <- read_u32()
    read_u32()                          # AddressOfFunctions
    names_rva <- read_u32()
    if (num_names <= 0L) {
      stop("DLL has no named exports: ", dll_path, call. = FALSE)
    }
    seek(con, rva_to_offset(names_rva))
    name_rvas <- readBin(con, integer(), n = num_names,
                         size = 4L, endian = "little")

    read_cstring <- function(file_offset) {
      seek(con, file_offset)
      bytes <- readBin(con, raw(), n = 1024L)  # exported names are short
      nul <- which(bytes == as.raw(0L))
      if (length(nul) == 0L) {
        stop("Unterminated export-name string at offset ",
             file_offset, call. = FALSE)
      }
      rawToChar(bytes[seq_len(nul[[1L]] - 1L)])
    }
    vapply(name_rvas,
           function(rva) read_cstring(rva_to_offset(rva)),
           character(1L))
  }

  # Locate dlltool from PATH or under Rtools.
  find_dlltool <- function() {
    path <- Sys.which("dlltool")
    if (nzchar(path)) return(path)
    rtools <- Sys.getenv("RTOOLS45_HOME",
                         Sys.getenv("RTOOLS_HOME", "C:/rtools45"))
    cand <- c(
      file.path(rtools, "x86_64-w64-mingw32.static.posix/bin/dlltool.exe"),
      file.path(rtools, "mingw64/bin/dlltool.exe"),
      file.path(rtools, "usr/bin/dlltool.exe")
    )
    hit <- cand[file.exists(cand)]
    if (length(hit) >= 1L) return(hit[[1L]])
    ""
  }

  # Write a Mingw .def file for `dlltool -d`.
  write_def_file <- function(def_path, dll_name, exports) {
    writeLines(
      c(paste0("LIBRARY \"", dll_name, "\""),
        "EXPORTS",
        paste0("    ", exports)),
      def_path
    )
  }

  fix_windows_dll <- function(extract_root) {
    if (tolower(Sys.info()[["sysname"]]) != "windows") return(invisible())

    src_dll <- file.path(extract_root, "bin", "pdfium.dll")
    src_lib <- file.path(extract_root, "lib", "pdfium.dll.lib")
    if (!file.exists(src_dll)) {
      warning("Expected bblanchon pdfium.dll not found at ", src_dll,
              "; Windows install will likely fail.", call. = FALSE)
      return(invisible())
    }

    dlltool <- find_dlltool()
    if (!nzchar(dlltool)) {
      stop("dlltool not found on PATH or under Rtools; cannot ",
           "regenerate the Mingw import library for pdfium.dll.",
           call. = FALSE)
    }

    # Rename pdfium.dll -> libpdfium.dll, kept in inst/bin/ until
    # src/install.libs.R relocates it.
    dst_dll <- file.path(extract_root, "bin", "libpdfium.dll")
    if (!file.copy(src_dll, dst_dll, overwrite = TRUE)) {
      stop("Failed to rename pdfium.dll to libpdfium.dll", call. = FALSE)
    }
    file.remove(src_dll)

    # Parse exports from the renamed DLL and write a .def file whose
    # LIBRARY directive matches the new filename.
    exports <- parse_pe_exports(dst_dll)
    defpath <- tempfile("libpdfium-", fileext = ".def")
    on.exit(unlink(defpath), add = TRUE)
    write_def_file(defpath, "libpdfium.dll", exports)

    # Generate the Mingw import library. `-D libpdfium.dll` bakes the
    # correct DLL name into the resulting `.dll.a`.
    out_lib <- file.path(extract_root, "lib", "libpdfium.dll.a")
    res <- system2(dlltool,
                   c("-d", shQuote(defpath),
                     "-l", shQuote(out_lib),
                     "-D", "libpdfium.dll"),
                   stdout = TRUE, stderr = TRUE)
    status <- attr(res, "status")
    if (!is.null(status) && status != 0L) {
      stop("dlltool failed: ", paste(res, collapse = "\n"), call. = FALSE)
    }

    # Drop bblanchon's stale MSVC import library.
    if (file.exists(src_lib)) file.remove(src_lib)

    message(sprintf(
      "[pdfium] Renamed pdfium.dll -> libpdfium.dll and regenerated import library (%d exports).",
      length(exports)
    ))
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
