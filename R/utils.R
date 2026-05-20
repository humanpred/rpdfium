# Argument validation across the package goes through `checkmate`
# directly at the call site — see ADR-010. Earlier ad-hoc helpers
# (validate_positive_int / _nonempty_char / _finite_numeric) were
# retired in the same pass; new code uses
# `checkmate::assert_count(x, positive = TRUE)` /
# `checkmate::assert_string(x, min.chars = 1L)` /
# `checkmate::assert_number(x, finite = TRUE)` instead.

# Internal: resolve a doc-or-path argument into an open `pdfium_doc`,
# scheduling `pdf_doc_close()` on the caller's exit when (and only when)
# this call opened the doc itself. Centralises the path-or-doc
# pattern used by every doc-or-path public function (pdf_page_count,
# pdf_doc_info, pdf_doc_bookmarks, pdf_attachments, pdf_doc_text, ...).
#
# `arg` is the public-facing argument name to surface in the
# assertion message when the caller passes something other than a
# `pdfium_doc`. `password` is only consulted on the path-string
# branch; if the caller already holds an open doc the password was
# supplied at open time.
#
# `.envir` is the frame the deferred close registers in — defaults
# to the caller's frame, which is what every callsite wants.
as_open_doc <- function(x, arg = "doc", password = NULL,
                        .envir = parent.frame(),
                        defer_close = TRUE) {
  if (is.character(x)) {
    doc <- pdf_doc_open(x, password = password)
    if (isTRUE(defer_close)) {
      withr::defer(pdf_doc_close(doc), envir = .envir)
    }
    return(doc)
  }
  checkmate::assert_class(x, "pdfium_doc", .var.name = arg)
  if (!is_open(x)) {
    stop("Document has been closed.", call. = FALSE)
  }
  x
}

# Internal: resolve a page-or-doc argument into an open `pdfium_page`,
# scheduling `pdf_page_close()` on the caller's exit when (and only
# when) this call loaded the page itself. The two-shape page
# argument (already-open page or doc-plus-index) is the convention
# used by every page-level wrapper in the package.
#
# `defer_close` controls whether to schedule a close in the caller's
# frame. Set to `FALSE` when the caller is returning a value that
# borrows the page's lifetime (e.g. `pdf_annotations()` returns a
# list of annot handles whose `prot` slots pin this page). The
# caller then has to keep the returned page reachable for the value
# to remain usable.
as_open_page <- function(page, page_num = 1L, .envir = parent.frame(),
                         defer_close = TRUE) {
  checkmate::assert_multi_class(page, c("pdfium_page", "pdfium_doc"))
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) stop("Page has been closed.", call. = FALSE)
    return(page)
  }
  # `page` is a pdfium_doc — load `page_num` and arrange for close.
  if (!is_open(page)) stop("Document has been closed.", call. = FALSE)
  p <- pdf_page_load(page, page_num)
  if (isTRUE(defer_close)) {
    withr::defer(pdf_page_close(p), envir = .envir)
  }
  p
}

# Internal: vectorised lookup of a PDFium integer enum code to its
# short character name. `names` is the lookup table; `base` is the
# integer code corresponding to `names[1]` (0 for most PDFium enums,
# 1 for FPDFACTION_* / FPDFDEST_VIEW_*). Out-of-range codes (whether
# negative, NA, or above `base + length(names) - 1`) collapse to
# `fallback`. Used by every `pdfium_*_name()` decoder.
.pdfium_enum_name <- function(codes, names, base = 0L,
                              fallback = "unknown") {
  codes <- as.integer(codes)
  out <- rep(fallback, length(codes))
  # nocov start — defensive against future PDFium enum extensions
  # above the current `length(names)` ceiling; today's codes always
  # land inside the table for every wrapper that calls us.
  hit <- !is.na(codes) & codes >= base & codes < base + length(names)
  out[hit] <- names[codes[hit] - base + 1L]
  # nocov end
  out
}

# Internal: replace empty strings (length-zero or `""`) with NA.
# PDFium reports "absent string entries" as `""`; callers typically
# want NA so downstream `is.na()` / tibble printing behaves sensibly.
# Works on length-N vectors and length-1 scalars uniformly.
na_if_empty <- function(x) {
  ifelse(nzchar(x), x, NA_character_)
}

# Internal: replace negative integers (PDFium's "no value" sentinel
# for many integer accessors — page index, parent index, MCID, ...)
# with NA. Coerces to integer first so numeric inputs work too.
na_if_negative <- function(x) {
  x <- as.integer(x)
  x[!is.na(x) & x < 0L] <- NA_integer_
  x
}

# Internal: assert that `key` is a non-empty single string AND
# re-encode it to UTF-8 ready for the PDFium C ABI (which expects
# UTF-8 byte sequences for every "name" argument — dict keys,
# attachment-dict keys, viewer-preference keys, etc.). Consolidates
# the assert-then-enc2utf8 pattern used in annot_probes.R,
# tier3_extras.R, and doc_extra.R.
assert_pdf_key <- function(key, arg = "key") {
  checkmate::assert_string(key, min.chars = 1L, .var.name = arg)
  enc2utf8(key)
}
