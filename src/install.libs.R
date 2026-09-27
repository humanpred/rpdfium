# src/install.libs.R
#
# Sourced by R CMD INSTALL after src/ compilation. R passes these
# variables in: R_PACKAGE_DIR, R_PACKAGE_NAME, R_PACKAGE_SOURCE,
# R_ARCH, SHLIB_EXT.
#
# Two responsibilities:
#   1. Install the package's compiled DLL (pdfium.so / .dylib / .dll)
#      into <pkg>/libs/<R_ARCH>/. R does NOT do this automatically
#      when install.libs.R exists - the script replaces R's default
#      install logic for src/-produced libraries.
#   2. On Windows only, also copy bblanchon's libpdfium.dll into
#      <pkg>/libs/<R_ARCH>/ so it sits next to the package's DLL.
#      Windows does not look for a DLL's dependencies in that DLL's
#      own directory. library.dynam() finds libpdfium.dll there
#      because it prepends <pkg>/libs/<R_ARCH> to PATH and calls
#      dyn.load(file, DLLpath = <pkg>/libs/<R_ARCH>), and R's
#      R_loadLibrary() wraps a plain LoadLibrary() in
#      SetDllDirectory(DLLpath). A bare dyn.load() without DLLpath
#      does not find it.
#
# On Linux/macOS, libpdfium.{so,dylib} remains in <pkg>/lib/ (copied
# from inst/lib by R's normal inst-tree copy). The RPATH embedded in
# pdfium.so / .dylib (`$ORIGIN/../lib`, `@loader_path/../lib`) finds
# it from the loading site at <pkg>/libs/<R_ARCH>/.

local({
  dest <- file.path(R_PACKAGE_DIR, paste0("libs", R_ARCH))
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  # 1. Install the package's own compiled DLL.
  shlib_name <- paste0(R_PACKAGE_NAME, SHLIB_EXT)
  shlib_src <- shlib_name
  if (!file.exists(shlib_src)) {
    arch_dir <- paste0("src", R_ARCH)
    if (file.exists(file.path(arch_dir, shlib_name))) {
      shlib_src <- file.path(arch_dir, shlib_name)
    }
  }
  if (!file.exists(shlib_src)) {
    stop(sprintf("install.libs.R: expected %s not found", shlib_name))
  }
  if (!file.copy(shlib_src, file.path(dest, shlib_name), overwrite = TRUE)) {
    stop(sprintf("install.libs.R: failed to copy %s into %s",
                 shlib_src, dest))
  }

  # 1b. Copy the per-object symbol table that R CMD INSTALL writes
  # when _R_SHLIB_BUILD_OBJECTS_SYMBOL_TABLES_=TRUE (the setting CRAN's
  # and r-universe's checks use). Without symbols.rds in the installed
  # libs/<arch>/, the check_compiled_code() pass on Windows can't see
  # what was in our .o files and falls back to scanning the .dll's
  # import table — which always contains _exit/abort/exit from the
  # MinGW static runtime, producing a spurious NOTE. Default R install
  # logic would copy this automatically; we replicate it here because
  # this script replaces that default.
  for (sym_src in c("symbols.rds", file.path(paste0("src", R_ARCH), "symbols.rds"))) {
    if (file.exists(sym_src)) {
      file.copy(sym_src, file.path(dest, "symbols.rds"), overwrite = TRUE)
      break
    }
  }

  # 2. Windows: copy bblanchon's libpdfium.dll next to our DLL.
  if (.Platform$OS.type == "windows") {
    pkg_root <- R_PACKAGE_SOURCE
    src_dll <- file.path(pkg_root, "inst", "bin", "libpdfium.dll")
    if (!file.exists(src_dll)) {
      stop("install.libs.R: inst/bin/libpdfium.dll not found. ",
           "Did tools/download-pdfium.R run?")
    }
    out <- file.path(dest, "libpdfium.dll")
    if (!file.copy(src_dll, out, overwrite = TRUE)) {
      stop(sprintf("install.libs.R: failed to copy %s into %s",
                   src_dll, dest))
    }
    message(sprintf("[pdfium] installed libpdfium.dll -> %s", dest))
  }
})
