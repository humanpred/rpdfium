#!/usr/bin/env Rscript
# tools/check-pkgdown-reference.R
#
# Validates that every exported function in NAMESPACE is mentioned in
# _pkgdown.yml's `reference:` section, and that the reference section
# doesn't list anything that isn't exported. This is the fast subset
# of pkgdown::check_pkgdown() that catches the "missing topic" /
# "stale reference" classes of drift without invoking pkgdown's full
# build pipeline.
#
# Entry point for the corresponding pre-commit hook in
# .pre-commit-config.yaml. Exits 0 when the reference index matches
# NAMESPACE exports, 1 with a diagnostic when it does not.
#
# Skips silently when:
#   - _pkgdown.yml is absent (e.g. early-stage projects)
#   - NAMESPACE is absent (e.g. before the first devtools::document())
#   - the yaml R package is not installed (developer can install with
#     `install.packages("yaml")`; CI still catches drift via pkgdown)

local({
  if (!file.exists("_pkgdown.yml")) return(invisible())
  if (!file.exists("NAMESPACE"))    return(invisible())
  if (!requireNamespace("yaml", quietly = TRUE)) {
    message("[check-pkgdown-reference] `yaml` package not installed; ",
            "skipping. Install with install.packages(\"yaml\") to enable.")
    return(invisible())
  }

  cfg <- yaml::read_yaml("_pkgdown.yml")
  ref <- cfg$reference
  if (is.null(ref)) {
    # No reference section declared. Nothing to validate; pkgdown
    # will fall back to an alphabetical auto-index.
    return(invisible())
  }

  # Flatten every `contents:` list under each reference entry.
  yaml_topics <- unique(unlist(lapply(ref, function(entry) entry$contents),
                               use.names = FALSE))
  yaml_topics <- yaml_topics[!is.na(yaml_topics) & nzchar(yaml_topics)]

  ns_lines <- readLines("NAMESPACE")
  # `exportPattern` and `exportClasses` not handled - this hook is
  # for the typical case where pdfium's exports are all `export(name)`.
  exports <- sub("^export\\(([^)]+)\\)$", "\\1",
                 grep("^export\\(", ns_lines, value = TRUE))

  missing_in_yaml  <- setdiff(exports, yaml_topics)
  unknown_in_yaml  <- setdiff(yaml_topics, exports)

  problems <- character()
  if (length(missing_in_yaml) > 0L) {
    problems <- c(problems, sprintf(
      "Exported but not in _pkgdown.yml reference index: %s",
      paste(missing_in_yaml, collapse = ", ")))
  }
  if (length(unknown_in_yaml) > 0L) {
    problems <- c(problems, sprintf(
      "In _pkgdown.yml reference index but not an export: %s",
      paste(unknown_in_yaml, collapse = ", ")))
  }
  if (length(problems) > 0L) {
    for (p in problems) message("[check-pkgdown-reference] ", p)
    message("[check-pkgdown-reference] Add the entries to a `reference:` ",
            "block's `contents:` list, or mark with @keywords internal ",
            "to drop from the index.")
    quit(status = 1L, save = "no")
  }
})
