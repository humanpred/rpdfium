#!/usr/bin/env Rscript
# tools/check-rd-xrefs.R
#
# Validates that every \link{} target in every Rd file under man/
# resolves — either to a topic in this package, to a topic in a
# documented dependency, or to one of the base / recommended
# packages.
#
# Catches the same class of WARNING that `R CMD check --as-cran`
# emits under "checking Rd cross-references":
#
#     Found the following Rd file(s) with Rd \link{} targets
#     missing package anchors:
#       pdf_X.Rd: some_unresolved_topic
#
# That WARNING fails the cross-platform R-CMD-check matrix on every
# CI platform — better to catch it on the developer's machine.
#
# Uses `tools:::.check_Rd_xrefs()` (R-internal) which is the same
# function `R CMD check` itself invokes for this check. It only
# needs the source tree (no install / no compile), so it's
# cheap enough to run on every push.
#
# Entry point for the corresponding pre-commit hook in
# .pre-commit-config.yaml. Exits 0 when every Rd cross-reference
# resolves; 1 with a diagnostic when at least one does not.
#
# Skips silently when:
#   - the `tools` package isn't available (shouldn't happen — it's
#     bundled with base R, but defensive nonetheless)
#   - the package has no DESCRIPTION (run from somewhere other than
#     a package root)

local({
  if (!file.exists("DESCRIPTION")) {
    message("[check-rd-xrefs] Not in a package root; skipping.")
    return(invisible())
  }
  # `tools:::.check_Rd_xrefs` is internal; existence-check first.
  fn <- tryCatch(
    get(".check_Rd_xrefs", envir = asNamespace("tools"),
        inherits = FALSE),
    error = function(e) NULL
  )
  if (is.null(fn)) {
    message("[check-rd-xrefs] tools:::.check_Rd_xrefs not available ",
            "in this R; skipping. R-CMD-check on CI will still catch.")
    return(invisible())
  }

  result <- fn(dir = ".")
  if (length(result$bad) == 0L) {
    return(invisible())
  }

  for (rd_file in names(result$bad)) {
    topics <- result$bad[[rd_file]]
    # Topics arrive as a named character; the names are the report
    # categories (`report`, `legacy`, etc.) and the values are the
    # unresolved topic strings.
    for (topic in unique(topics)) {
      message(sprintf(
        "[check-rd-xrefs] %s: unresolved \\link{} target '%s'",
        rd_file, topic
      ))
    }
  }
  message("[check-rd-xrefs] Fix by either qualifying the link with ",
          "a package name (e.g. [graphics::plot()]), pointing it at ",
          "an actual Rd topic in this package, or replacing the link ",
          "with plain `code` formatting if the target has no Rd page.")
  quit(status = 1L, save = "no")
})
