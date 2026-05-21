# Document-level accessors that don't fit cleanly under document.R
# (the metadata module). Three independent features:
#
#   pdf_doc_bookmarks(doc)       table of contents
#   pdf_page_label(doc, n)   logical page label like "i", "1", "A-1"
#   pdf_doc_permissions(doc) named logical of allowed operations
#
# Each takes either an open `pdfium_doc` or a path. Path input is
# convenience for one-shot inspection: the doc is opened, the
# accessor runs, and the doc is closed before returning.

#' List the bookmark outline (table of contents) of a PDF
#'
#' Returns a `pdfium_bookmark_list` — a list of `pdfium_bookmark`
#' handles, one per bookmark in the document's outline tree, walked
#' depth-first. Per-attribute getters
#' ([pdf_bookmark_title()], [pdf_bookmark_page_num()],
#' [pdf_bookmark_action_type()], [pdf_bookmark_uri()],
#' [pdf_bookmark_filepath()], [pdf_bookmark_dest_view()],
#' [pdf_bookmark_dest_x()], [pdf_bookmark_dest_y()],
#' [pdf_bookmark_dest_zoom()]) operate on a single handle.
#'
#' The list is flat; the tree shape is recovered from each handle's
#' `parent_index` field. Top-level bookmarks have `parent_index == 0`;
#' every other bookmark's parent is the entry whose `index` matches
#' its `parent_index`. `level` is the 1-based nesting depth.
#'
#' Use `tibble::as_tibble(pdf_doc_bookmarks(doc))` for the tibble
#' view.
#'
#' Wraps `FPDFBookmark_GetFirstChild`, `FPDFBookmark_GetNextSibling`,
#' `FPDFBookmark_GetTitle`, `FPDFBookmark_GetDest`,
#' `FPDFBookmark_GetAction`, `FPDFAction_GetType` /
#' `FPDFAction_GetURIPath` / `FPDFAction_GetFilePath`, and
#' `FPDFDest_GetDestPageIndex`.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @return A `pdfium_bookmark_list` (empty if no outline).
#' @seealso [pdf_page_labels()] for logical page numbering,
#'   [pdf_page_links()] for clickable link annotations on a page,
#'   [pdf_parse_date()] for parsing date-shaped action strings.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "outline.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_doc_bookmarks(fixture)
#' @export
pdf_doc_bookmarks <- function(doc) {
  doc <- as_open_doc(doc, defer_close = FALSE)
  raw <- cpp_bookmark_handles(doc$ptr)
  ptrs    <- raw$handles
  parents <- as.integer(raw$parent_indices)
  levels  <- as.integer(raw$levels)
  handles <- lapply(seq_along(ptrs), function(i) {
    new_pdfium_bookmark(ptrs[[i]], doc,
                        index        = i,
                        parent_index = parents[[i]],
                        level        = levels[[i]])
  })
  new_pdfium_bookmark_list(handles, doc)
}

#' Tibble view of a `pdfium_bookmark_list`
#'
#' Walks every bookmark in the list and reads its metadata into a
#' tibble. Adds `handle` and `source` list-columns (ADR-017).
#'
#' @param x A `pdfium_bookmark_list` from [pdf_doc_bookmarks()].
#' @param ... Unused (S3 generic compatibility).
#' @return A tibble with the documented bookmark columns plus
#'   `handle` and `source`.
#' @importFrom tibble as_tibble
#' @method as_tibble pdfium_bookmark_list
#' @export
as_tibble.pdfium_bookmark_list <- function(x, ...) {
  src_doc <- attr(x, "source")
  if (length(x) == 0L) {
    return(empty_bookmark_tibble())
  }
  info <- lapply(x, function(bm) {
    cpp_bookmark_action_handle(bm$ptr, src_doc$ptr)
  })
  titles <- vapply(x, function(bm) cpp_bookmark_title_handle(bm$ptr),
                   character(1L))
  action_codes <- vapply(info, `[[`, integer(1L), "action_code")
  page_nums    <- vapply(info, `[[`, integer(1L), "page_num")
  uris         <- vapply(info, `[[`, character(1L), "uri")
  filepaths    <- vapply(info, `[[`, character(1L), "filepath")
  dest_views   <- vapply(info, `[[`, integer(1L), "dest_view")
  dest_xs      <- vapply(info, `[[`, numeric(1L), "dest_x")
  dest_ys      <- vapply(info, `[[`, numeric(1L), "dest_y")
  dest_zooms   <- vapply(info, `[[`, numeric(1L), "dest_zoom")
  tibble::tibble(
    bookmark_index = seq_along(x),
    parent_index   = vapply(x, `[[`, integer(1L), "parent_index"),
    level          = vapply(x, `[[`, integer(1L), "level"),
    title          = titles,
    page_num       = na_if_negative(ifelse(page_nums < 0L,
                                            page_nums,
                                            page_nums + 1L)),
    action_type    = pdfium_action_type_name(action_codes),
    uri            = na_if_empty(uris),
    filepath       = na_if_empty(filepaths),
    dest_view      = pdfium_dest_view_name(dest_views),
    dest_x         = dest_xs,
    dest_y         = dest_ys,
    dest_zoom      = dest_zooms,
    handle         = unclass(x),
    source         = rep(list(src_doc), length(x))
  )
}

empty_bookmark_tibble <- function() {
  tibble::tibble(
    bookmark_index = integer(),
    parent_index   = integer(),
    level          = integer(),
    title          = character(),
    page_num       = integer(),
    action_type    = character(),
    uri            = character(),
    filepath       = character(),
    dest_view      = character(),
    dest_x         = numeric(),
    dest_y         = numeric(),
    dest_zoom      = numeric(),
    handle         = list(),
    source         = list()
  )
}

#' Coerce input to a `pdfium_bookmark_list`
#'
#' Reverse companion to [as_tibble.pdfium_bookmark_list()].
#'
#' @param x Either a `pdfium_bookmark_list`, a list of
#'   `pdfium_bookmark` handles, or a tibble with a `handle`
#'   list-column.
#' @return A `pdfium_bookmark_list`.
#' @export
as_pdfium_bookmark_list <- function(x) {
  if (inherits(x, "pdfium_bookmark_list")) return(x)
  if (is.list(x) && length(x) > 0L &&
      all(vapply(x, inherits, logical(1L), "pdfium_bookmark"))) {
    src_doc <- x[[1L]]$doc
    return(new_pdfium_bookmark_list(x, src_doc))
  }
  if (tibble::is_tibble(x) && "handle" %in% names(x)) {
    handles <- x$handle
    if (length(handles) == 0L) {
      stop("Cannot rebuild a `pdfium_bookmark_list` from a zero-",
           "row tibble (source doc unknown).", call. = FALSE)
    }
    src_doc <- x$source[[1L]]
    return(new_pdfium_bookmark_list(handles, src_doc))
  }
  stop("`x` must be a `pdfium_bookmark_list`, a list of ",
       "`pdfium_bookmark`, or a tibble produced by ",
       "`as_tibble(pdf_doc_bookmarks(doc))`.", call. = FALSE)
}

# Internal validator
check_bookmark <- function(bm, arg = "bm") {
  checkmate::assert_class(bm, "pdfium_bookmark", .var.name = arg)
  if (!is_open(bm)) {
    stop("Bookmark handle has been closed.", call. = FALSE)
  }
  invisible(bm)
}

# Internal: pull the action/dest bundle for a single handle.
bookmark_action_info <- function(bm) {
  cpp_bookmark_action_handle(bm$ptr, bm$doc$ptr)
}

#' Bookmark display title
#'
#' Returns the bookmark's display text (UTF-8). Wraps
#' `FPDFBookmark_GetTitle`.
#'
#' @param bm A `pdfium_bookmark` handle from [pdf_doc_bookmarks()].
#' @return Character scalar.
#' @export
pdf_bookmark_title <- function(bm) {
  check_bookmark(bm)
  cpp_bookmark_title_handle(bm$ptr)
}

#' Bookmark destination page number
#'
#' Returns the 1-based page number the bookmark resolves to, or
#' `NA_integer_` when the bookmark has no resolvable in-document
#' destination (URI / launch actions, or unresolvable
#' /Dest entries).
#'
#' @inheritParams pdf_bookmark_title
#' @return Integer scalar (1-based) or `NA`.
#' @export
pdf_bookmark_page_num <- function(bm) {
  check_bookmark(bm)
  page <- bookmark_action_info(bm)$page_num
  if (page < 0L) NA_integer_ else as.integer(page + 1L)
}

#' Bookmark action type
#'
#' Returns one of `"goto"`, `"remote_goto"`, `"uri"`, `"launch"`,
#' `"embedded_goto"`, or `"unsupported"`. Wraps
#' `FPDFAction_GetType`.
#'
#' @inheritParams pdf_bookmark_title
#' @return Character scalar.
#' @export
pdf_bookmark_action_type <- function(bm) {
  check_bookmark(bm)
  pdfium_action_type_name(bookmark_action_info(bm)$action_code)
}

#' Bookmark URI (for URI actions)
#'
#' Returns the action's target URL when the bookmark is a URI
#' action, else `NA_character_`. Wraps `FPDFAction_GetURIPath`.
#'
#' @inheritParams pdf_bookmark_title
#' @return Character scalar or `NA`.
#' @export
pdf_bookmark_uri <- function(bm) {
  check_bookmark(bm)
  na_if_empty(bookmark_action_info(bm)$uri)
}

#' Bookmark external file path
#'
#' Returns the external file path when the bookmark action is
#' `"remote_goto"`, `"launch"`, or `"embedded_goto"`, else
#' `NA_character_`. Wraps `FPDFAction_GetFilePath`.
#'
#' @inheritParams pdf_bookmark_title
#' @return Character scalar or `NA`.
#' @export
pdf_bookmark_filepath <- function(bm) {
  check_bookmark(bm)
  na_if_empty(bookmark_action_info(bm)$filepath)
}

#' Bookmark destination view mode
#'
#' Returns the destination view mode (one of `"xyz"`, `"fit"`,
#' `"fith"`, `"fitv"`, `"fitr"`, `"fitb"`, `"fitbh"`, `"fitbv"`,
#' `"unknown"`). Wraps `FPDFDest_GetView`.
#'
#' @inheritParams pdf_bookmark_title
#' @return Character scalar.
#' @export
pdf_bookmark_dest_view <- function(bm) {
  check_bookmark(bm)
  pdfium_dest_view_name(bookmark_action_info(bm)$dest_view)
}

#' Bookmark destination x coordinate
#'
#' Returns the X coordinate of the destination for XYZ / FitR /
#' FitBH destinations; `NA` for view modes that don't carry one.
#' Wraps `FPDFDest_GetLocationInPage`.
#'
#' @inheritParams pdf_bookmark_title
#' @return Numeric scalar or `NA`.
#' @export
pdf_bookmark_dest_x <- function(bm) {
  check_bookmark(bm)
  bookmark_action_info(bm)$dest_x
}

#' Bookmark destination y coordinate
#'
#' Returns the Y coordinate of the destination for XYZ / FitR /
#' FitBV destinations; `NA` for view modes that don't carry one.
#' Wraps `FPDFDest_GetLocationInPage`.
#'
#' @inheritParams pdf_bookmark_title
#' @return Numeric scalar or `NA`.
#' @export
pdf_bookmark_dest_y <- function(bm) {
  check_bookmark(bm)
  bookmark_action_info(bm)$dest_y
}

#' Bookmark destination zoom factor
#'
#' Returns the zoom factor for XYZ destinations; `NA` for view
#' modes that don't carry one. Wraps `FPDFDest_GetLocationInPage`.
#'
#' @inheritParams pdf_bookmark_title
#' @return Numeric scalar or `NA`.
#' @export
pdf_bookmark_dest_zoom <- function(bm) {
  check_bookmark(bm)
  bookmark_action_info(bm)$dest_zoom
}

#' Read the logical page label of a PDF page
#'
#' PDFs distinguish "physical" page numbers (1, 2, 3, ...) from
#' "logical" labels (e.g. "i", "ii", "iii" for front-matter then
#' "1", "2", "3" for the body, or "A-1", "A-2" for an appendix).
#' Wraps `FPDF_GetPageLabel`.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @param page_num One-based physical page index (default `1`).
#' @return Character scalar - the page's logical label, UTF-8
#'   encoded. Empty string when the PDF doesn't carry a labels
#'   table for this page (PDFium falls back to the physical
#'   number's string form in some cases, but the contract is "may
#'   be empty").
#' @seealso [pdf_page_labels()] for every page's label at once,
#'   [pdf_doc_bookmarks()].
#' @export
pdf_page_label <- function(doc, page_num = 1L) {
  checkmate::assert_count(page_num, positive = TRUE)
  doc <- as_open_doc(doc)
  cpp_page_label(doc$ptr, as.integer(page_num) - 1L)
}

#' Read every page's logical label in one call
#'
#' Convenience wrapper that calls [pdf_page_label()] for every page
#' of the document and returns the results as a character vector
#' (positionally aligned: element `i` is the label of page `i`).
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @return Character vector of length `pdf_page_count(doc)`.
#' @seealso [pdf_page_label()] for a single page.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_page_labels(fixture)
#' @export
pdf_page_labels <- function(doc) {
  doc <- as_open_doc(doc)
  n <- cpp_page_count(doc$ptr)
  vapply(
    seq_len(n),
    function(i) cpp_page_label(doc$ptr, i - 1L),
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
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character path.
#' @return A named logical vector with the eight flags listed above.
#' @export
pdf_doc_permissions <- function(doc) {
  doc <- as_open_doc(doc)
  # cpp_doc_permissions returns the raw unsigned 32-bit mask as a
  # double (R's integer cannot hold 0xFFFFFFFF). All documented
  # permission bits are in bits 1-16, so reduce to the low 16 bits
  # via `mask %% 65536` before passing to bitwAnd. For unencrypted
  # documents PDFium returns 0xFFFFFFFF and the low-16 reduction
  # gives 0xFFFF -- every flag is set, every operation allowed,
  # which is the correct contract.
  mask <- cpp_doc_permissions(doc$ptr)
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
  doc <- as_open_doc(doc)
  decode_perm_mask(cpp_doc_user_permissions(doc$ptr))
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
  doc <- as_open_doc(doc)
  rev <- as.integer(cpp_doc_security_revision(doc$ptr))
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
  doc <- as_open_doc(doc)
  as.logical(cpp_doc_xref_valid(doc$ptr))
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
  doc <- as_open_doc(doc)
  cpp_doc_trailer_ends(doc$ptr)
}

#' One-call summary of a PDF document
#'
#' Returns a single-row tibble that aggregates the most-asked-for
#' facts about a PDF document: file path, page count, Info-dictionary
#' metadata, structural feature flags (forms, attachments, bookmarks,
#' signatures, JavaScript, tagged-PDF), counts for each of those
#' feature groups, encryption state, and the file-ID tuple. Designed
#' to replace the eight-or-so individual calls users typically chain
#' together when triaging a PDF.
#'
#' Each column either exposes an existing reader or is a `length()`
#' over the matching `pdfium_*_list`. No new C-side work — purely an
#' R-side aggregation. See **Columns** below for the source reader
#' for each entry.
#'
#' @section Columns:
#' * `path` — character; canonical path the doc was opened from, or
#'   `"<raw bytes>"` for in-memory loads.
#' * `page_count`, `file_version` — from [pdf_doc_info()].
#' * `title`, `author`, `subject`, `keywords`, `creator`, `producer`,
#'   `creation_date`, `mod_date`, `trapped` — from [pdf_doc_info()];
#'   missing entries appear as `""`.
#' * `creation_date_parsed`, `mod_date_parsed` — POSIXct (UTC), `NA`
#'   when the source date is empty or unparseable. From
#'   [pdf_parse_date()].
#' * `is_tagged` — from [pdf_doc_is_tagged()].
#' * `is_encrypted` — `TRUE` when [pdf_doc_security()] returns a
#'   non-NA revision; `FALSE` otherwise.
#' * `security_revision` — from [pdf_doc_security()]; `NA` for
#'   unencrypted PDFs.
#' * `xref_valid` — from [pdf_doc_xref_valid()].
#' * `bookmark_count`, `attachment_count`, `signature_count`,
#'   `form_field_count`, `javascript_count`, `named_dest_count` —
#'   `length()` of [pdf_doc_bookmarks()], [pdf_attachments()],
#'   [pdf_signatures()], [pdf_form_fields()], [pdf_doc_javascript()],
#'   and [pdf_doc_named_dests()] respectively. Zero when the
#'   document has none of the corresponding entries.
#' * `has_page_labels` — `TRUE` when [pdf_page_labels()] returns
#'   non-NA strings.
#' * `file_id_permanent`, `file_id_changing` — from
#'   [pdf_doc_file_id()]; UTF-8 hex strings or `NA`.
#'
#' @param doc A `pdfium_doc` from [pdf_doc_open()], or a character
#'   path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is an open `pdfium_doc`.
#' @return A one-row tibble.
#' @seealso [pdf_doc_info()] for the Info-dictionary subset alone,
#'   the per-feature readers listed under **Columns** for richer
#'   per-row data.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "annotated.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_doc_summary(fixture)
#' @export
pdf_doc_summary <- function(doc, password = NULL) {
  if (is.character(doc)) {
    handle <- pdf_doc_open(doc, password = password)
    on.exit(pdf_doc_close(handle), add = TRUE)
    return(pdf_doc_summary(handle))
  }
  checkmate::assert_class(doc, "pdfium_doc")
  if (!is_open(doc)) stop("Document has been closed.", call. = FALSE)

  info <- pdf_doc_info(doc)
  rev <- pdf_doc_security(doc)
  page_labels <- tryCatch(pdf_page_labels(doc),
                          error = function(e) NULL)
  file_id <- list(
    permanent = file_id_hex_or_na(tryCatch(
      pdf_doc_file_id(doc, "permanent"),
      error = function(e) raw(0)
    )),
    changing = file_id_hex_or_na(tryCatch(
      pdf_doc_file_id(doc, "changing"),
      error = function(e) raw(0)
    ))
  )

  tibble::tibble(
    path                 = doc$path,
    page_count           = info$page_count,
    file_version         = info$file_version,
    title                = info$title %||% "",
    author               = info$author %||% "",
    subject              = info$subject %||% "",
    keywords             = info$keywords %||% "",
    creator              = info$creator %||% "",
    producer             = info$producer %||% "",
    creation_date        = info$creation_date %||% "",
    mod_date             = info$mod_date %||% "",
    trapped              = info$trapped %||% "",
    creation_date_parsed = info$creation_date_parsed,
    mod_date_parsed      = info$mod_date_parsed,
    is_tagged            = pdf_doc_is_tagged(doc),
    is_encrypted         = !is.na(rev),
    security_revision    = rev,
    xref_valid           = pdf_doc_xref_valid(doc),
    bookmark_count       = length(pdf_doc_bookmarks(doc)),
    attachment_count     = length(pdf_attachments(doc)),
    signature_count      = length(pdf_signatures(doc)),
    form_field_count     = length(pdf_form_fields(doc)),
    javascript_count     = length(pdf_doc_javascript(doc)),
    named_dest_count     = length(pdf_doc_named_dests(doc)),
    has_page_labels      = !is.null(page_labels) &&
                             any(!is.na(page_labels) & nzchar(page_labels)),
    file_id_permanent    = file_id$permanent,
    file_id_changing     = file_id$changing
  )
}

# Internal: tiny version of rlang's %||% so we don't pull rlang in
# just for the summary path. Returns `b` when `a` is NULL or NA.
`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
}

#' Document-level summary
#'
#' `summary()` method for `pdfium_doc`. Defers to
#' [pdf_doc_summary()] so users can call `summary(doc)` for the
#' single-row tibble of every key fact about the PDF — page count,
#' Info-dictionary metadata, structural feature flags, per-feature
#' counts, the file-ID tuple — in one call.
#'
#' @param object A `pdfium_doc` from [pdf_doc_open()].
#' @param ... Unused (S3 generic compatibility).
#' @return The tibble returned by [pdf_doc_summary()].
#' @seealso [pdf_doc_summary()].
#' @export
summary.pdfium_doc <- function(object, ...) {
  pdf_doc_summary(object)
}

# Internal: convert pdf_doc_file_id()'s raw return to a hex string,
# or NA_character_ when empty. Hoisted from pdf_doc_summary so its
# two branches can be unit-tested without a fixture that carries an
# `/ID` array (no shipped fixture does).
file_id_hex_or_na <- function(r) {
  if (length(r) == 0L) {
    return(NA_character_)
  }
  paste(format(r), collapse = "")
}
