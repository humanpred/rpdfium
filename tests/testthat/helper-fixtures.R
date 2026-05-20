# tests/testthat/helper-fixtures.R
#
# Fixture-loading helpers. Sourced into every parallel testthat worker
# before its first test file runs. Cache results per-worker; never across
# workers.

# Per-worker memoization. `local()` keeps the cache scoped to this file's
# environment so each worker process gets its own copy automatically.
.fixture_cache <- new.env(parent = emptyenv())

#' Path to a bundled fixture PDF
#'
#' Resolves a fixture by short name. Errors loudly if the file doesn't
#' exist — fixtures should be reproducible-by-construction via
#' `tools/build-fixtures.R`.
#'
#' @param name Short fixture name (without extension), e.g. "minimal".
#' @return Absolute path to the PDF.
fixture_path <- function(name) {
  cached <- .fixture_cache[[name]]
  if (!is.null(cached) && file.exists(cached)) {
    return(cached)
  }

  candidates <- c(
    system.file("extdata", "fixtures", paste0(name, ".pdf"), package = "pdfium"),
    file.path("..", "..", "inst", "extdata", "fixtures", paste0(name, ".pdf"))
  )
  for (p in candidates) {
    if (nzchar(p) && file.exists(p)) {
      .fixture_cache[[name]] <- normalizePath(p, winslash = "/", mustWork = TRUE)
      return(.fixture_cache[[name]])
    }
  }
  testthat::skip(sprintf("Fixture %s.pdf not available", name))
}
