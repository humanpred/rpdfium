# Document-level accessors that don't fit cleanly under document.R
# (the metadata module). Three independent features:
#
#   pdf_bookmarks(doc)       table of contents
#   pdf_page_label(doc, n)   logical page label like "i", "1", "A-1"
#   pdf_doc_permissions(doc) named logical of allowed operations
#
# Each takes either an open `pdfium_doc` or a path. Path input is
# convenience for one-shot inspection: the doc is opened, the
# accessor runs, and the doc is closed before returning.

# Internal: accept either an open pdfium_doc or a character path,
# return a (doc, on_exit) pair where `on_exit` is a closure the
# caller invokes when finished. Centralises the path-or-doc
# pattern used by pdf_page_count(), pdf_doc_info(), and the three
# accessors below.
as_doc_handle <- function(x, arg = "doc") {
  if (is.character(x)) {
    doc <- pdf_open(x)
    return(list(doc = doc, on_exit = function() pdf_close(doc)))
  }
  checkmate::assert_class(x, "pdfium_doc", .var.name = arg)
  if (!is_open(x)) {
    stop("Document has been closed.", call. = FALSE)
  }
  list(doc = x, on_exit = function() invisible(NULL))
}

#' Read the bookmark outline (table of contents) of a PDF
#'
#' Returns a tibble row per bookmark, walking PDFium's outline tree
#' depth-first. Each row carries the bookmark's title, its position
#' in the hierarchy, the page it points to (when resolvable), and the
#' action it carries (URI, launch, remote_goto, embedded_goto, or
#' the typical goto-within-this-document).
#'
#' The tree structure is recoverable from the `parent_index` column
#' alone: top-level bookmarks have `parent_index == 0`, and every
#' other bookmark's parent is the row whose `bookmark_index` matches
#' its `parent_index`. The `level` column is a convenience for
#' filtering ("show me chapter-level entries only").
#'
#' Wraps `FPDFBookmark_GetFirstChild`, `FPDFBookmark_GetNextSibling`,
#' `FPDFBookmark_GetTitle`, `FPDFBookmark_GetDest`,
#' `FPDFBookmark_GetAction`, `FPDFAction_GetType` /
#' `FPDFAction_GetURIPath` / `FPDFAction_GetFilePath`, and
#' `FPDFDest_GetDestPageIndex`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @return A tibble with columns:
#'   * `bookmark_index` integer - 1-based pre-order index across the
#'     entire outline tree.
#'   * `parent_index` integer - `bookmark_index` of the parent
#'     entry, or `0` for top-level bookmarks.
#'   * `level` integer - 1-based nesting depth.
#'   * `title` character - the bookmark's display text, UTF-8.
#'   * `page_num` integer - 1-based destination page number, or
#'     `NA` when the bookmark has no resolvable page destination
#'     (e.g. for URI / launch actions, or unresolvable dests).
#'   * `action_type` character - one of `"goto"`, `"remote_goto"`,
#'     `"uri"`, `"launch"`, `"embedded_goto"`.
#'   * `uri` character - the action's target URL when
#'     `action_type == "uri"`; `NA` otherwise.
#'   * `filepath` character - the external file path when
#'     `action_type` is `"remote_goto"` / `"launch"` /
#'     `"embedded_goto"`; `NA` otherwise.
#'   * `dest_view` character - the destination view mode (one of
#'     `"xyz"`, `"fit"`, `"fith"`, `"fitv"`, `"fitr"`, `"fitb"`,
#'     `"fitbh"`, `"fitbv"`, `"unknown"`).
#'   * `dest_x`, `dest_y`, `dest_zoom` numeric - the explicit point
#'     / zoom for XYZ destinations and the line offset for
#'     FitH / FitV / FitBH / FitBV. `NA` for components the
#'     destination doesn't specify.
#'
#' Returns a 0-row tibble of the same schema when the document has
#' no outline.
#'
#' @seealso [pdf_page_labels()] for logical page numbering,
#'   [pdf_page_links()] for clickable link annotations on a page.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "outline.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_bookmarks(fixture)
#' @export
pdf_bookmarks <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  raw <- cpp_bookmarks(h$doc$ptr)
  page_num <- raw$page_num
  page_num[page_num < 0L] <- NA_integer_

  uri <- raw$uri
  uri <- ifelse(nzchar(uri), uri, NA_character_)
  filepath <- raw$filepath
  filepath <- ifelse(nzchar(filepath), filepath, NA_character_)

  # action_code 0 means "no /A and unresolvable /Dest" — surface as
  # "unsupported" via the shared lookup. URI / filepath columns are
  # NA in that case anyway.
  action_codes <- as.integer(raw$action_code)
  action_type <- pdfium_action_type_name(action_codes)

  tibble::tibble(
    bookmark_index = seq_along(raw$title),
    parent_index   = as.integer(raw$parent_index),
    level          = as.integer(raw$level),
    title          = raw$title,
    page_num       = as.integer(page_num),
    action_type    = action_type,
    uri            = uri,
    filepath       = filepath,
    dest_view      = pdfium_dest_view_name(raw$dest_view),
    dest_x         = raw$dest_x,
    dest_y         = raw$dest_y,
    dest_zoom      = raw$dest_zoom
  )
}

#' Read the logical page label of a PDF page
#'
#' PDFs distinguish "physical" page numbers (1, 2, 3, ...) from
#' "logical" labels (e.g. "i", "ii", "iii" for front-matter then
#' "1", "2", "3" for the body, or "A-1", "A-2" for an appendix).
#' Wraps `FPDF_GetPageLabel`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param page_num One-based physical page index (default `1`).
#' @return Character scalar - the page's logical label, UTF-8
#'   encoded. Empty string when the PDF doesn't carry a labels
#'   table for this page (PDFium falls back to the physical
#'   number's string form in some cases, but the contract is "may
#'   be empty").
#' @seealso [pdf_page_labels()] for every page's label at once,
#'   [pdf_bookmarks()].
#' @export
pdf_page_label <- function(doc, page_num = 1L) {
  checkmate::assert_count(page_num, positive = TRUE)
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  cpp_page_label(h$doc$ptr, as.integer(page_num) - 1L)
}

#' Read every page's logical label in one call
#'
#' Convenience wrapper that calls [pdf_page_label()] for every page
#' of the document and returns the results as a character vector
#' (positionally aligned: element `i` is the label of page `i`).
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @return Character vector of length `pdf_page_count(doc)`.
#' @seealso [pdf_page_label()] for a single page.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_page_labels(fixture)
#' @export
pdf_page_labels <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  n <- cpp_page_count(h$doc$ptr)
  vapply(
    seq_len(n),
    function(i) cpp_page_label(h$doc$ptr, i - 1L),
    character(1L)
  )
}

# PDF spec 7.6.3.2 / Table 22: meaning of each /P (UserAccess) bit
# in the encryption dictionary. The other bits are reserved or
# always set; PDFium returns them unchanged. We decode the bits
# that have a documented user-facing meaning.
.pdfium_permission_bits <- c(
  print            =  3L,
  modify           =  4L,
  copy             =  5L,
  annotate         =  6L,
  fill_forms       =  9L,
  extract_for_a11y = 10L,
  assemble         = 11L,
  print_high_res   = 12L
)

#' Permission flags from a PDF's encryption dictionary
#'
#' Returns the operations the PDF declares it allows. When the
#' document is unencrypted (or was opened with the owner password),
#' PDFium reports `0xFFFFFFFF` - every bit set, every operation
#' allowed - and this function returns a named logical vector of
#' all `TRUE`. For an encrypted document opened with a user
#' password, the bitmask reflects whatever the document author set.
#'
#' Wraps `FPDF_GetDocPermissions`. The decoded flags follow the PDF
#' specification's `/P` (UserAccess) bit assignments (ISO 32000-1
#' section 7.6.3.2, Table 22):
#'
#' * `print` - bit 3: print the document.
#' * `modify` - bit 4: change content other than annotation /
#'   form-field values.
#' * `copy` - bit 5: copy or otherwise extract text and graphics
#'   from the document.
#' * `annotate` - bit 6: add or modify text annotations.
#' * `fill_forms` - bit 9: fill in interactive form fields,
#'   regardless of `modify`.
#' * `extract_for_a11y` - bit 10: extract text and graphics for
#'   accessibility purposes.
#' * `assemble` - bit 11: insert, rotate, or delete pages and
#'   create bookmarks / thumbnails, regardless of `modify`.
#' * `print_high_res` - bit 12: faithful digital print copy. When
#'   `FALSE` while `print` is `TRUE`, the document may print only
#'   at low resolution.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @return A named logical vector with the eight flags listed above.
#' @export
pdf_doc_permissions <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  # cpp_doc_permissions returns the raw unsigned 32-bit mask as a
  # double (R's integer cannot hold 0xFFFFFFFF). All documented
  # permission bits are in bits 1-16, so reduce to the low 16 bits
  # via `mask %% 65536` before passing to bitwAnd. For unencrypted
  # documents PDFium returns 0xFFFFFFFF and the low-16 reduction
  # gives 0xFFFF -- every flag is set, every operation allowed,
  # which is the correct contract.
  mask <- cpp_doc_permissions(h$doc$ptr)
  decode_perm_mask(mask)
}

# Internal: shared low-16-bit decode used by pdf_doc_permissions()
# and pdf_doc_user_permissions().
decode_perm_mask <- function(mask) {
  low16 <- as.integer(mask %% 65536)
  vapply(
    .pdfium_permission_bits,
    function(b) bitwAnd(low16, bitwShiftL(1L, b - 1L)) != 0L,
    logical(1L)
  )
}

#' User-level document permissions
#'
#' Returns the *user* subset of the document's permission bitmask
#' (the bits that apply to a user who opened the PDF without the
#' owner password). Same shape as [pdf_doc_permissions()] — a named
#' logical vector with one entry per permission flag — but with
#' owner-only operations cleared. Wraps `FPDF_GetDocUserPermissions`.
#'
#' For unencrypted PDFs, every flag is `TRUE`.
#'
#' @inheritParams pdf_doc_permissions
#' @return Named logical vector. Same names as
#'   [pdf_doc_permissions()].
#' @seealso [pdf_doc_permissions()], [pdf_doc_security()].
#' @export
pdf_doc_user_permissions <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  decode_perm_mask(cpp_doc_user_permissions(h$doc$ptr))
}

#' Document security handler revision
#'
#' Returns the PDF security handler revision used by the document:
#'
#' * `NA` — unencrypted (PDFium reports `-1`, mapped to `NA` here).
#' * `2` — original 40-bit RC4 (PDF 1.1).
#' * `3` — 128-bit RC4 (PDF 1.4).
#' * `4` — AES (PDF 1.6).
#' * `5` — AES-256, Adobe Extension Level 3 (PDF 1.7).
#' * `6` — AES-256 (PDF 2.0).
#'
#' Wraps `FPDF_GetSecurityHandlerRevision`. Useful when classifying
#' PDFs as "encrypted vs not" and when reporting the encryption
#' strength to downstream tools — combine with [pdf_doc_permissions()]
#' to know whether a viewer would let a user print/copy/edit.
#'
#' @inheritParams pdf_doc_permissions
#' @return Integer scalar. `NA` for unencrypted PDFs; one of
#'   `2`, `3`, `4`, `5`, `6` otherwise.
#' @seealso [pdf_doc_permissions()], [pdf_doc_user_permissions()].
#' @export
pdf_doc_security <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  rev <- as.integer(cpp_doc_security_revision(h$doc$ptr))
  # nocov start — non-NA branch needs an encrypted PDF; the
  # fixture pipeline doesn't ship one. Behaviour verified against
  # encrypted PDFs in ad-hoc local testing.
  if (rev >= 0L) {
    return(rev)
  }
  # nocov end
  NA_integer_
}

#' Cross-reference table validity flag
#'
#' Returns `TRUE` when the document's `/XRef` table is structurally
#' valid as PDFium found it, or `FALSE` when PDFium had to rebuild
#' it from scratch (a sign of a damaged or non-conforming PDF).
#' Wraps `FPDF_DocumentHasValidCrossReferenceTable`.
#'
#' @inheritParams pdf_doc_permissions
#' @return Logical scalar.
#' @export
pdf_doc_xref_valid <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  as.logical(cpp_doc_xref_valid(h$doc$ptr))
}

#' Byte offsets of every `%%EOF` trailer marker
#'
#' Returns one integer per trailer end-of-file marker in the source
#' bytes. A clean single-revision PDF reports one value. Incremental
#' updates append additional bodies / xref tables and trailers, each
#' marked by another `%%EOF`. Wraps `FPDF_GetTrailerEnds`.
#'
#' Useful for incremental-update analysis, signature byte-range
#' validation, and PDF repair workflows.
#'
#' @inheritParams pdf_doc_permissions
#' @return Integer vector of byte offsets (one per trailer). Empty
#'   when PDFium reports none. Returns `NA` for any offset that
#'   exceeds R's 32-bit signed integer range (files larger than
#'   2 GB).
#' @export
pdf_doc_trailer_ends <- function(doc) {
  h <- as_doc_handle(doc, "doc")
  on.exit(h$on_exit(), add = TRUE)
  cpp_doc_trailer_ends(h$doc$ptr)
}
