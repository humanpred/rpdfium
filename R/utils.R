# Argument validation across the package goes through `checkmate`
# directly at the call site — see ADR-010. Earlier ad-hoc helpers
# (validate_positive_int / _nonempty_char / _finite_numeric) were
# retired in the same pass; new code uses
# `checkmate::assert_count(x, positive = TRUE)` /
# `checkmate::assert_string(x, min.chars = 1L)` /
# `checkmate::assert_number(x, finite = TRUE)` instead.

# Internal: accept either an open pdfium_doc or a character path,
# return a (doc, on_exit) pair where `on_exit` is a closure the
# caller invokes when finished. Centralises the path-or-doc pattern
# used by every doc-or-path public function (pdf_page_count(),
# pdf_doc_info(), pdf_bookmarks(), pdf_attachments(), pdf_text(),
# pdf_annotations(), ...).
#
# `arg` is the public-facing argument name to surface in the
# assertion message when the caller passes something other than a
# `pdfium_doc`. `password` is only consulted on the path-string
# branch; if the caller already holds an open doc the password
# was already supplied at open time.
as_doc_handle <- function(x, arg = "doc", password = NULL) {
  if (is.character(x)) {
    doc <- pdf_open(x, password = password)
    return(list(doc = doc, on_exit = function() pdf_close(doc)))
  }
  checkmate::assert_class(x, "pdfium_doc", .var.name = arg)
  if (!is_open(x)) {
    stop("Document has been closed.", call. = FALSE)
  }
  list(doc = x, on_exit = function() invisible(NULL))
}

# Internal: resolve a page-or-doc argument into an open page plus a
# `close_on_exit` flag the caller uses to decide whether to free
# what it got back. The two-shape page argument (already-open page
# or doc-plus-index) is the convention used by every page-level
# wrapper that doesn't need the `.close_on_exit` attribute form
# from R/objects.R::as_open_page.
as_open_page_pair <- function(page, page_num) {
  checkmate::assert_multi_class(page, c("pdfium_page", "pdfium_doc"))
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) stop("Page has been closed.", call. = FALSE)
    return(list(page = page, close_on_exit = FALSE))
  }
  # `page` is a pdfium_doc — load `page_num` and arrange for close.
  if (!is_open(page)) stop("Document has been closed.", call. = FALSE)
  p <- pdf_load_page(page, page_num)
  list(page = p, close_on_exit = TRUE)
}
