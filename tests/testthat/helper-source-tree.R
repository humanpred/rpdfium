#' Path to `...` inside the package's source tree, or `""` outside one.
#'
#' `devtools::test()` runs from the source tree; `R CMD check` runs the
#' tests next to the unpacked source under `00_pkg_src/`. An installed
#' package has no source tree, so callers skip on `""`.
source_tree_path <- function(...) {
  candidates <- c(
    testthat::test_path("..", "..", ...),
    testthat::test_path("..", "..", "00_pkg_src", "pdfium", ...)
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0L) "" else normalizePath(hit[[1L]])
}
