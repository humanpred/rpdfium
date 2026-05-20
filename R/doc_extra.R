# Extra document-level accessors added in the phase-6 polish pass.
# Each takes either an open `pdfium_doc` or a path, like the other
# doc-level functions, and surfaces a single PDFium fact about
# the document.

#' Read every page's text in one call
#'
#' Convenience wrapper that returns the document's text content
#' one string per page, matching the shape of
#' `pdftools::pdf_text()`. Each element is the concatenated text
#' of every text run on the corresponding page, joined with `"\n"`
#' between runs.
#'
#' Internally walks the document with [pdf_text_runs()] to reuse
#' the batched text-page load.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return Character vector of length `pdf_page_count(doc)`. Each
#'   element is UTF-8 encoded.
#' @seealso [pdf_text_runs()] for run-level structure (font,
#'   bounding box).
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_text(fixture)
#' @export
pdf_text <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  n <- cpp_page_count(doc$ptr)
  vapply(seq_len(n), function(i) {
    page <- pdf_load_page(doc, i)
    on.exit(pdf_close_page(page))
    runs <- pdf_text_runs(page)
    if (nrow(runs) == 0L) "" else paste(runs$text, collapse = "\n")
  }, character(1L))
}

#' Document-level rollup of every embedded / referenced font
#'
#' Returns one tibble row per distinct font used anywhere in the
#' document, with the same metadata columns
#' [pdf_text_runs()]/[pdf_text_font()] report at the run/object
#' level. Useful for porting from `pdftools::pdf_fonts()`.
#'
#' Two fonts are treated as distinct when any of `font_base_name`,
#' `font_family`, `font_weight`, `font_italic_angle`,
#' `font_is_embedded`, or `font_flags` differ. The first page on
#' which each font appears is recorded in `first_seen_page`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A tibble with columns: `font_base_name`, `font_family`,
#'   `font_weight`, `font_italic_angle`, `font_is_embedded`,
#'   `font_flags`, `first_seen_page` (1-based).
#' @seealso [pdf_text_runs()], [pdf_text_font()].
#' @export
pdf_fonts <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  n <- cpp_page_count(doc$ptr)
  all_runs <- list()
  for (i in seq_len(n)) {
    page <- pdf_load_page(doc, i)
    runs <- pdf_text_runs(page)
    pdf_close_page(page)
    if (nrow(runs) > 0L) {
      runs$first_seen_page <- i
      all_runs[[length(all_runs) + 1L]] <- runs
    }
  }
  if (length(all_runs) == 0L) {
    return(tibble::tibble(
      font_base_name    = character(),
      font_family       = character(),
      font_weight       = integer(),
      font_italic_angle = integer(),
      font_is_embedded  = logical(),
      font_flags        = integer(),
      first_seen_page   = integer()
    ))
  }
  combined <- do.call(rbind, all_runs)
  font_cols <- c(
    "font_base_name", "font_family", "font_weight",
    "font_italic_angle", "font_is_embedded",
    "font_flags"
  )
  # Deduplicate on the full font tuple, taking the smallest
  # first_seen_page for each unique combination.
  key <- do.call(paste, c(combined[font_cols], sep = ""))
  first_idx <- !duplicated(key)
  out <- combined[first_idx, c(font_cols, "first_seen_page"),
    drop = FALSE
  ]
  rownames(out) <- NULL
  tibble::as_tibble(out)
}

#' Read the document's file identifier from its trailer
#'
#' Returns the raw bytes of the PDF trailer's `/ID` entry. The
#' identifier is a two-element array `[permanent, changing]`:
#' `permanent` is a hash that should stay constant across saves
#' of the same logical document; `changing` is updated each time
#' the file is rewritten. Use `id_type = "permanent"` (the
#' default) to track document identity, or `"changing"` to detect
#' that the file has been re-saved.
#'
#' Wraps `FPDF_GetFileIdentifier`. The identifier is binary; PDF
#' writers conventionally produce 16-byte MD5 hashes but the
#' length is unspecified and PDFs from non-standard writers may
#' return any byte string (or none at all).
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param id_type One of `"permanent"` (default) or `"changing"`.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A raw vector. Zero-length when the document has no
#'   `/ID` entry.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) pdf_file_id(fixture)
#' @export
pdf_file_id <- function(doc, id_type = c("permanent", "changing"),
                        password = NULL) {
  id_type <- match.arg(id_type)
  type_code <- if (identical(id_type, "permanent")) 0L else 1L
  doc <- as_open_doc(doc, password = password)
  cpp_doc_file_id(doc$ptr, type_code)
}

# PDFium FPDFDoc_GetPageMode values from fpdf_ext.h.
.pdfium_page_modes <- c(
  "unknown", # -1 PAGEMODE_UNKNOWN (only on error)
  "use_none", #  0 PAGEMODE_USENONE
  "use_outlines", #  1 PAGEMODE_USEOUTLINES
  "use_thumbs", #  2 PAGEMODE_USETHUMBS
  "full_screen", #  3 PAGEMODE_FULLSCREEN
  "use_oc", #  4 PAGEMODE_USEOC
  "use_attachments" #  5 PAGEMODE_USEATTACHMENTS
)

#' Read the document's PageMode entry from its catalog
#'
#' The PageMode tells a PDF viewer how to display the document on
#' open: just the content, the outline panel beside it, the
#' thumbnails panel, full-screen, the optional-content panel, or
#' the attachments panel. Wraps `FPDFDoc_GetPageMode`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return Character scalar - one of `"use_none"`,
#'   `"use_outlines"`, `"use_thumbs"`, `"full_screen"`,
#'   `"use_oc"` (optional-content panel), `"use_attachments"`, or
#'   `"unknown"` (PDFium couldn't determine the entry).
#' @export
pdf_doc_page_mode <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  # PDFium's enum starts at -1 (PAGEMODE_UNKNOWN); we offset by 1 so
  # the lookup begins at index 0, matching .pdfium_enum_name()'s
  # default `base = 0L`. The first lookup entry is "unknown" and
  # acts as the in-range UNKNOWN; the fallback path fires only on
  # codes above the current ceiling.
  .pdfium_enum_name(cpp_doc_page_mode(doc$ptr) + 1L, .pdfium_page_modes)
}

# Duplex mode codes from FPDF_DUPLEXTYPE in fpdf_doc.h
# (DuplexUndefined=0, Simplex=1, DuplexFlipShortEdge=2,
# DuplexFlipLongEdge=3). Bumped to 1-based index in pdf_viewer_preferences().
.pdfium_duplex_modes <- c(
  "none", # 0 DuplexUndefined
  "simplex", # 1 Simplex
  "duplex_flip_short_edge", # 2 DuplexFlipShortEdge
  "duplex_flip_long_edge" # 3 DuplexFlipLongEdge
)

# Internal: idx -> duplex name. Callers pass a 1-based index into
# .pdfium_duplex_modes, so we shift to .pdfium_enum_name's 0-based
# convention.
decode_duplex <- function(idx) {
  .pdfium_enum_name(idx - 1L, .pdfium_duplex_modes, fallback = "none")
}

#' Is the document marked as tagged?
#'
#' Reports whether the PDF catalog's `/MarkInfo` entry advertises
#' the document as tagged (i.e., it carries a structure tree usable
#' for accessibility/reflow). Wraps `FPDFCatalog_IsTagged`. Note
#' that a "tagged" advertisement is not a guarantee that the
#' structure tree is well-formed.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return Logical scalar.
#' @export
pdf_doc_is_tagged <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  cpp_doc_is_tagged(doc$ptr)
}

#' Read the document's viewer preferences
#'
#' Returns the print-related preferences encoded in the PDF's
#' ViewerPreferences dictionary: whether the viewer should honor the
#' author's print scaling, the suggested number of copies, the
#' paper-handling (duplex) option, and the print-page-range
#' specification. Wraps the `FPDF_VIEWERREF_*` family.
#'
#' Most PDFs don't set these; the returned defaults are PDFium's
#' "no preference" sentinels: `print_scaling = TRUE`,
#' `num_copies = 1`, `duplex = "none"`, `print_page_ranges` empty.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A named list with:
#'   * `print_scaling` (logical) — TRUE if the author wants the
#'     viewer's print dialog to use its default scaling.
#'   * `num_copies` (integer) — suggested copies; 1 if not set.
#'   * `duplex` (character) — one of `"none"`, `"simplex"`,
#'     `"duplex_flip_short_edge"`, `"duplex_flip_long_edge"`.
#'   * `print_page_ranges` (integer) — 1-based page numbers the
#'     author suggests printing; empty when unspecified.
#' @export
pdf_viewer_preferences <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  raw <- cpp_doc_viewer_prefs(doc$ptr)
  idx <- raw$duplex_code + 1L
  duplex <- decode_duplex(idx)
  list(
    print_scaling      = as.logical(raw$print_scaling),
    num_copies         = as.integer(raw$num_copies),
    duplex             = duplex,
    print_page_ranges  = as.integer(raw$print_page_ranges)
  )
}

#' Look up a `/ViewerPreferences` name-typed entry by key
#'
#' PDFium's structured [pdf_viewer_preferences()] surfaces the
#' commonly-used entries (print scaling, copies, duplex, page
#' ranges). For other keys whose value is a `/Name` (e.g. `Direction`
#' = `"L2R"`/`"R2L"`, `ViewArea` = `"MediaBox"`/`"CropBox"`, or
#' arbitrary author-defined entries), use this by-key lookup.
#' Wraps `FPDF_VIEWERREF_GetName`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param key The viewer-preferences dictionary key as a single
#'   non-empty character string (ASCII PDF name, e.g.
#'   `"Direction"`).
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return Character scalar — the entry's name value (without the
#'   leading slash), or `NA_character_` when the key is absent or
#'   the value is not a `/Name`.
#' @seealso [pdf_viewer_preferences()].
#' @export
pdf_viewer_preference_by_name <- function(doc, key, password = NULL) {
  key <- assert_pdf_key(key)
  doc <- as_open_doc(doc, password = password)
  out <- cpp_viewer_ref_name(doc$ptr, key)
  # nocov start — non-NA branch requires a fixture whose
  # /ViewerPreferences carries a Name-typed entry (e.g. Direction
  # = /L2R). The shipped fixtures don't set one. Behaviour
  # verified against ad-hoc Acrobat-emitted PDFs.
  if (nzchar(out)) {
    return(out)
  }
  # nocov end
  NA_character_
}

#' Enumerate the document's named destinations
#'
#' PDF authors can attach named "destinations" to specific page
#' positions (e.g. for cross-document links or programmatic
#' navigation). Returns one row per named destination with its name,
#' target page, and the dest's view/zoom parameters. Wraps
#' `FPDF_CountNamedDests` / `FPDF_GetNamedDest` /
#' `FPDFDest_GetDestPageIndex` / `FPDFDest_GetView` /
#' `FPDFDest_GetLocationInPage`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A tibble with columns:
#'   * `name` character - the destination name, UTF-8.
#'   * `page` integer - 1-based target page; `NA` when PDFium
#'     can't resolve it.
#'   * `dest_view` character - the dest's view mode: one of
#'     `"xyz"`, `"fit"`, `"fith"`, `"fitv"`, `"fitr"`, `"fitb"`,
#'     `"fitbh"`, `"fitbv"`, or `"unknown"`.
#'   * `dest_x`, `dest_y` numeric - the explicit (x, y) point for
#'     XYZ destinations and the line offset for FitH / FitV /
#'     FitBH / FitBV. `NA` when not specified by the destination.
#'   * `dest_zoom` numeric - the explicit zoom for XYZ destinations,
#'     `NA` otherwise.
#' @export
pdf_named_dests <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  raw <- cpp_doc_named_dests(doc$ptr)
  page <- raw$page_index_zero
  has_page <- !is.na(page)
  page[has_page] <- page[has_page] + 1L
  tibble::tibble(
    name      = raw$name,
    page      = page,
    dest_view = pdfium_dest_view_name(raw$dest_view),
    dest_x    = raw$dest_x,
    dest_y    = raw$dest_y,
    dest_zoom = raw$dest_zoom
  )
}

#' Enumerate document-level JavaScript actions
#'
#' Returns one row per JavaScript action attached to the document
#' (typically OpenAction or Document JS). Useful for static analysis
#' of PDFs that may contain executable JavaScript. PDFium never
#' executes the script; this is a passive readout. Wraps
#' `FPDFDoc_GetJavaScriptAction*` / `FPDFJavaScriptAction_GetName` /
#' `_GetScript`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A tibble with columns `name` (UTF-8 action name, often
#'   empty for the top-level OpenAction) and `script` (the
#'   JavaScript source, UTF-8). Empty tibble when no JS actions
#'   are present.
#' @export
pdf_doc_javascript <- function(doc, password = NULL) {
  doc <- as_open_doc(doc, password = password)
  raw <- cpp_doc_javascript(doc$ptr)
  tibble::tibble(name = raw$name, script = raw$script)
}
