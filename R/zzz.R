# nocov start
.onLoad <- function(libname, pkgname) {
  # On Windows the package's compiled pdfium.dll has a delay-load
  # import descriptor for libpdfium.dll (see src/Makevars.win). We
  # preload the bundled libpdfium.dll from <pkg>/bin/ here so that
  # when the first FPDF_* call below triggers the delay-load stub,
  # Windows finds the already-resolved module by name.
  if (.Platform$OS.type == "windows") {
    libpdfium <- system.file("bin", "libpdfium.dll", package = pkgname,
                             lib.loc = libname, mustWork = FALSE)
    if (nzchar(libpdfium) && file.exists(libpdfium)) {
      dyn.load(libpdfium)
    }
  }
  cpp_init_library()
  invisible()
}

.onUnload <- function(libpath) {
  cpp_destroy_library()
  library.dynam.unload("pdfium", libpath)
  if (.Platform$OS.type == "windows") {
    libpdfium <- file.path(libpath, "bin", "libpdfium.dll")
    if (file.exists(libpdfium)) try(dyn.unload(libpdfium), silent = TRUE)
  }
  invisible()
}
# nocov end
