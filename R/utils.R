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

# Argument validation across the package goes through `checkmate`
# directly at the call site — see ADR-010. Earlier ad-hoc helpers
# (validate_positive_int / _nonempty_char / _finite_numeric) were
# retired in the same pass; new code uses
# `checkmate::assert_count(x, positive = TRUE)` /
# `checkmate::assert_string(x, min.chars = 1L)` /
# `checkmate::assert_number(x, finite = TRUE)` instead.
