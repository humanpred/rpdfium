#' Resolve the bundled PDFium binary directory
#'
#' Returns the path inside the installed package where the configure script
#' deposited `libpdfium.{so,dylib,dll}` and the public headers. Mostly useful
#' for diagnostics — the package itself locates the library through the
#' regular linker / `library.dynam` machinery.
#'
#' @return A character scalar — the absolute path to the `lib/` directory
#'   under `inst/`. Empty string if the package was not installed.
#' @keywords internal
#' @noRd
pdfium_lib_dir <- function() {
  system.file("lib", package = "pdfium")
}
