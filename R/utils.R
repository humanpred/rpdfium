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

# Shared input-validation helpers used across the wrappers. Kept
# small and self-explanatory so they don't bloat the cyclomatic
# complexity of the surrounding public functions.

# Internal: stop unless `value` is a single positive finite numeric
# that's >= 1.
validate_positive_int <- function(value, arg_name) {
  ok <- is.numeric(value) && length(value) == 1L &&
    is.finite(value) && value >= 1L
  if (!ok) {
    stop(sprintf("`%s` must be a single positive integer.", arg_name),
      call. = FALSE
    )
  }
  invisible(NULL)
}

# Internal: stop unless `value` is a single non-NA non-empty character.
validate_nonempty_char <- function(value, arg_name) {
  ok <- is.character(value) && length(value) == 1L &&
    !is.na(value) && nzchar(value)
  if (!ok) {
    stop(
      sprintf(
        "`%s` must be a single non-empty character string.",
        arg_name
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

# Internal: stop unless `value` is a single finite numeric.
validate_finite_numeric <- function(value, arg_name) {
  ok <- is.numeric(value) && length(value) == 1L && is.finite(value)
  if (!ok) {
    stop(sprintf("`%s` must be a single finite numeric.", arg_name),
      call. = FALSE
    )
  }
  invisible(NULL)
}
