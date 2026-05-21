#' Load a single page from an open PDF document
#'
#' Returns a `pdfium_page` handle bound to its parent `doc`. The page is
#' garbage-collected with a finalizer that calls `FPDF_ClosePage`; call
#' [pdf_page_close()] explicitly when you need deterministic release.
#' The page keeps the parent document alive for as long as the page
#' is reachable, so it is safe to drop your reference to `doc` while
#' still holding a page.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()].
#' @param page_num One-based page index. Must satisfy
#'   `1 <= page_num <= pdf_page_count(doc)`.
#' @return A `pdfium_page` object.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_doc_open(fixture)
#'   page <- pdf_page_load(doc, 1)
#'   pdf_page_close(page)
#'   pdf_doc_close(doc)
#' }
#' @export
pdf_page_load <- function(doc, page_num = 1L) {
  checkmate::assert_class(doc, "pdfium_doc")
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  checkmate::assert_count(page_num, positive = TRUE)
  page_num <- as.integer(page_num)
  n <- cpp_page_count(doc$ptr)
  if (page_num > n) {
    stop(sprintf(
      "`page_num` (%d) exceeds the document's page count (%d).",
      page_num, n
    ), call. = FALSE)
  }
  ptr <- cpp_load_page(doc$ptr, page_num - 1L)
  new_pdfium_page(ptr, doc, page_num)
}

#' Close a page handle
#'
#' Releases the underlying PDFium handle. Idempotent — calling
#' `pdf_page_close()` on an already-closed page is a no-op.
#'
#' @param page A `pdfium_page` from [pdf_page_load()].
#' @return Invisibly returns `page` with its underlying pointer marked closed.
#' @export
pdf_page_close <- function(page) {
  checkmate::assert_class(page, "pdfium_page")
  # Deregister from the doc's open-pages map BEFORE closing so a
  # racing pdf_save() doesn't pick up a stale externalptr. Only
  # remove if the entry actually points at this page's externalptr
  # — another open handle for the same page index may have
  # registered itself more recently.
  state <- page$doc$state
  if (!is.null(state)) {
    key <- as.character(page$index)
    registered <- state$open_pages[[key]]
    if (!is.null(registered) && identical(registered, page$ptr)) {
      state$open_pages[[key]] <- NULL
    }
  }
  cpp_close_page(page$ptr)
  invisible(page)
}

#' Page dimensions in PDF points
#'
#' Returns the width and height of `page` in PDF points (1 point = 1/72 inch).
#' Accepts either a `pdfium_page` (preferred when you already have one) or
#' a `(doc, page)` pair (convenience for one-shot inspection).
#'
#' The returned dimensions are **media-box** dimensions in the page's
#' default (un-rotated) orientation. If the page has a non-zero
#' rotation (via the PDF `/Rotate` attribute or PDFium's runtime
#' rotation), `pdf_page_size()` does not swap width and height. Query
#' the rotation separately with [pdf_page_rotation()] if you need to
#' know the on-screen orientation.
#'
#' @param page A `pdfium_page` from [pdf_page_load()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A named numeric vector with elements `width` and
#'   `height`.
#'
#' @seealso [pdf_page_rotation()] for the rotation angle in degrees.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_doc_open(fixture)
#'   pdf_page_size(doc, 1)
#'   pdf_doc_close(doc)
#' }
#' @export
pdf_page_size <- function(page, page_num = 1L) {
  checkmate::assert_multi_class(page, c("pdfium_page", "pdfium_doc"))
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) stop("Page has been closed.", call. = FALSE)
    return(cpp_page_size(page$ptr))
  }
  # `page` is a pdfium_doc.
  if (!is_open(page)) stop("Document has been closed.", call. = FALSE)
  # Fast path: FPDF_GetPageSizeByIndexF reports the page's media
  # extents without loading the page object, which is much
  # cheaper than pdf_page_load + cpp_page_size for callers
  # iterating dimensions across many pages.
  cpp_doc_page_size_by_index(page$ptr, as.integer(page_num - 1L))
}

#' Page rotation in degrees
#'
#' Returns the page's rotation as `0`, `90`, `180`, or `270` degrees.
#' PDFium reports the rotation stored in the page's `/Rotate` entry
#' combined with any runtime rotation applied via the editing API.
#'
#' A non-zero rotation means [pdf_page_size()]'s `width` and `height`
#' refer to the page's pre-rotation media box, not the on-screen
#' dimensions a viewer would display. For an "as-displayed" size, swap
#' `width` and `height` when rotation is `90` or `270`.
#'
#' @param page A `pdfium_page` from [pdf_page_load()], or a
#'   `pdfium_doc`.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return An integer in `{0, 90, 180, 270}`.
#'
#' @seealso [pdf_page_size()] for the un-rotated dimensions.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_doc_open(fixture)
#'   pdf_page_rotation(doc, 1)
#'   pdf_doc_close(doc)
#' }
#' @export
pdf_page_rotation <- function(page, page_num = 1L) {
  checkmate::assert_multi_class(page, c("pdfium_page", "pdfium_doc"))
  if (inherits(page, "pdfium_page")) {
    if (!is_open(page)) stop("Page has been closed.", call. = FALSE)
    return(cpp_page_rotation(page$ptr))
  }
  # `page` is a pdfium_doc.
  p <- pdf_page_load(page, page_num)
  on.exit(pdf_page_close(p), add = TRUE)
  cpp_page_rotation(p$ptr)
}

#' One-call summary of every page in a document
#'
#' Returns a tibble with one row per page covering the cheap
#' per-page facts: width, height (both in PDF user-space points,
#' pre-rotation), rotation in degrees, and the page label (if any).
#' The per-page values come from the existing single-page readers
#' [pdf_page_size()] (fast `FPDF_GetPageSizeByIndexF` path),
#' [pdf_page_rotation()], and [pdf_page_labels()]; no per-page
#' [pdf_page_load()] is required for any of them, so the function
#' is efficient on long documents.
#'
#' For deeper per-page facts (annotation count, object count, text
#' content, …) load each page individually with [pdf_page_load()]
#' and call the per-page readers.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character
#'   path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is an open `pdfium_doc`.
#' @return A tibble with columns:
#'   * `page_num` — integer, 1-based.
#'   * `width`, `height` — numeric, PDF user-space points.
#'   * `rotation` — integer, `0` / `90` / `180` / `270`.
#'   * `label` — character; the page's `/PageLabels` entry, or `NA`
#'     when the document has no labels.
#' @seealso [pdf_doc_summary()] for the doc-level companion;
#'   [pdf_page_size()], [pdf_page_rotation()], [pdf_page_labels()]
#'   for the per-row readers.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_pages_summary(fixture)
#' @export
pdf_pages_summary <- function(doc, password = NULL) {
  if (is.character(doc)) {
    handle <- pdf_doc_open(doc, password = password)
    on.exit(pdf_doc_close(handle), add = TRUE)
    return(pdf_pages_summary(handle))
  }
  checkmate::assert_class(doc, "pdfium_doc")
  if (!is_open(doc)) stop("Document has been closed.", call. = FALSE)

  n <- pdf_page_count(doc)
  labels <- tryCatch(pdf_page_labels(doc), error = function(e) NULL)
  if (is.null(labels) || length(labels) != n) {
    # nocov start — pdf_page_labels always returns a length-n vector
    # on shipped fixtures (every doc has a /PageLabels array, even
    # if every entry is ""); guard exists for malformed PDFs in the
    # wild.
    labels <- rep(NA_character_, n)
    # nocov end
  }
  # Some labels arrive as "" when the source PDF has a /PageLabels
  # array that omits a specific page. Surface those as NA for a
  # cleaner "no label here" signal.
  labels[!is.na(labels) & !nzchar(labels)] <- NA_character_

  if (n == 0L) {
    return(empty_pages_summary())  # nocov — no shipped fixture has 0 pages.
  }

  # Use the fast by-index size / rotation paths so we never load a
  # page object just to read its metadata.
  sizes <- lapply(seq_len(n), function(i) pdf_page_size(doc, i))
  rotations <- vapply(seq_len(n), function(i) {
    as.integer(pdf_page_rotation(doc, i))
  }, integer(1L))

  tibble::tibble(
    page_num = seq_len(n),
    width    = vapply(sizes, function(s) as.numeric(s[["width"]]),
                       numeric(1L)),
    height   = vapply(sizes, function(s) as.numeric(s[["height"]]),
                       numeric(1L)),
    rotation = rotations,
    label    = labels
  )
}

#' Page-level summary
#'
#' `summary()` method for `pdfium_page`. Returns a single-row tibble
#' combining the cheap by-index columns
#' ([pdf_pages_summary()]-style: `page_num`, `width`, `height`,
#' `rotation`, `label`) with the per-page counts that require the
#' page to be loaded — annotation count, page-object count, text-run
#' count, and link count. Because the page handle is already loaded,
#' the per-count readers run against the existing page and don't
#' trigger an additional load.
#'
#' Use this for the "what's on this page?" interactive triage flow.
#' For the doc-wide companion, see [summary.pdfium_doc()].
#'
#' @param object A `pdfium_page` from [pdf_page_load()].
#' @param ... Unused (S3 generic compatibility).
#' @return A one-row tibble with columns `page_num`, `width`,
#'   `height`, `rotation`, `label`, `annotation_count`, `obj_count`,
#'   `text_run_count`, `link_count`.
#' @seealso [summary.pdfium_doc()] for the doc-wide companion,
#'   [pdf_pages_summary()] for the per-document table without the
#'   page-loaded counts.
#' @export
summary.pdfium_page <- function(object, ...) {
  if (!is_open(object)) stop("Page has been closed.", call. = FALSE)
  sz <- cpp_page_size(object$ptr)
  labels <- tryCatch(pdf_page_labels(object$doc),
                     error = function(e) NULL)
  label <- if (is.null(labels) || length(labels) < object$index) {
    NA_character_  # nocov — shipped fixtures always return length-n.
  } else {
    lbl <- labels[[object$index]]
    if (is.na(lbl) || !nzchar(lbl)) NA_character_ else lbl
  }

  tibble::tibble(
    page_num         = object$index,
    width            = as.numeric(sz[["width"]]),
    height           = as.numeric(sz[["height"]]),
    rotation         = as.integer(cpp_page_rotation(object$ptr)),
    label            = label,
    annotation_count = length(pdf_annotations(object)),
    obj_count        = length(pdf_page_objects(object)),
    text_run_count   = nrow(pdf_text_runs(object)),
    link_count       = nrow(pdf_page_links(object))
  )
}

# Internal: zero-row tibble matching pdf_pages_summary's shape, for
# docs with no pages (rare; mostly an in-memory-built corner case).
empty_pages_summary <- function() {
  tibble::tibble(
    page_num = integer(),
    width    = numeric(),
    height   = numeric(),
    rotation = integer(),
    label    = character()
  )
}
