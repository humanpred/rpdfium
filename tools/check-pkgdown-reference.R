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

  # The canonical "what topics should pkgdown index" set is every
  # man/*.Rd file that isn't marked `\keyword{internal}`. Walking
  # the Rd files directly handles every topic-creation path
  # (`@export`, S3 methods registered via `@exportS3Method`, manual
  # `@aliases`/`@rdname`-collapsed methods) without having to
  # re-parse NAMESPACE's S3method dispatch records.
  rd_files <- list.files("man", pattern = "\\.Rd$", full.names = FALSE)
  rd_files <- rd_files[nzchar(rd_files)]
  if (length(rd_files) == 0L) {
    return(invisible())
  }

  # A topic in pkgdown's reference can be either the Rd file's
  # basename OR any \alias{} entry inside it (the @rdname-collapsed
  # case: when several R functions share one Rd file, every
  # function's name becomes an alias for the shared topic). Both
  # forms resolve, so both count as valid YAML entries.
  rd_topics_and_aliases <- function(rd_file) {
    lines <- readLines(file.path("man", rd_file), warn = FALSE)
    if (any(grepl("\\\\keyword\\{internal\\}", lines))) {
      return(character(0))
    }
    base <- sub("\\.Rd$", "", rd_file)
    aliases <- sub(".*\\\\alias\\{([^}]+)\\}.*", "\\1",
                   grep("\\\\alias\\{", lines, value = TRUE))
    unique(c(base, aliases))
  }
  topics <- unique(unlist(lapply(rd_files, rd_topics_and_aliases),
                          use.names = FALSE))

  missing_in_yaml  <- setdiff(topics, yaml_topics)
  unknown_in_yaml  <- setdiff(yaml_topics, topics)

  problems <- character()
  if (length(missing_in_yaml) > 0L) {
    problems <- c(problems, sprintf(
      "Documented but not in _pkgdown.yml reference index: %s",
      paste(missing_in_yaml, collapse = ", ")))
  }
  if (length(unknown_in_yaml) > 0L) {
    problems <- c(problems, sprintf(
      "In _pkgdown.yml reference index but no matching man/*.Rd: %s",
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
