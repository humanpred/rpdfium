# Foundation for the writer surface: pdf_save(), pdf_save_to_raw(),
# pdf_doc_new(), pdf_page_new(), plus the internal readwrite-state machinery.
#
# Layering:
#   * `pdf_open(..., readwrite = TRUE)` flips `doc$readwrite` to TRUE.
#   * Every mutator function calls `assert_readwrite(doc)` at the
#     top, raising if the doc was opened read-only.
#   * `pdf_save()` and `pdf_save_to_raw()` work on read-only docs
#     too — they don't mutate, they serialise. Useful when a user
#     wants to round-trip an unmodified file through PDFium (e.g.
#     to repair a broken xref).
#   * `pdf_save()` writes atomically: tempfile in destination dir,
#     `file.rename` on success, `unlink` on failure.

# FPDF_SaveAsCopy flags (see PDFium's public/fpdf_save.h):
#   FPDF_INCREMENTAL      = 1  — append an incremental update
#   FPDF_NO_INCREMENTAL   = 2  — rewrite the whole file
#   FPDF_REMOVE_SECURITY  = 4  — strip the encryption dict
#   FPDF_SUBSET_NEW_FONTS = 8  — subset newly-embedded fonts
.pdfium_save_flags <- c(
  incremental      = 1L,
  no_incremental   = 2L,
  remove_security  = 4L,
  subset_new_fonts = 8L
)

# Internal: encode a set of save flags from named logical arguments.
encode_save_flags <- function(incremental, remove_security,
                              subset_new_fonts) {
  flags <- 0L
  if (incremental) {
    flags <- bitwOr(flags, .pdfium_save_flags[["incremental"]])
  } else {
    flags <- bitwOr(flags, .pdfium_save_flags[["no_incremental"]])
  }
  if (remove_security) {
    flags <- bitwOr(flags, .pdfium_save_flags[["remove_security"]])
  }
  if (subset_new_fonts) {
    flags <- bitwOr(flags, .pdfium_save_flags[["subset_new_fonts"]])
  }
  flags
}

# Internal: guard helper. Every mutator calls this first. Lives here
# rather than in R/utils.R because every reader of this file expects
# the readwrite contract to be visible alongside `pdf_save()`.
assert_readwrite <- function(doc, .var.name = "doc") {
  checkmate::assert_class(doc, "pdfium_doc", .var.name = .var.name)
  if (!isTRUE(doc$readwrite)) {
    stop(
      "Document opened read-only; ",
      "reopen with `pdf_open(..., readwrite = TRUE)`.",
      call. = FALSE
    )
  }
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  invisible(doc)
}

#' Save a PDF document to disk
#'
#' Serialises an in-memory `pdfium_doc` (typically produced by
#' [pdf_open()] with `readwrite = TRUE` and one or more mutators)
#' to a file. Wraps `FPDF_SaveAsCopy` and `FPDF_SaveWithVersion`.
#'
#' `pdf_save()` writes atomically: PDFium's bytes go into a
#' tempfile in the destination directory, and on success the
#' tempfile is renamed over `file`. If the save fails mid-write,
#' the original `file` (if any) is preserved untouched.
#'
#' Works on read-only documents too — opening a PDF, calling
#' `pdf_save()`, and re-opening the result is a way to "normalise"
#' a PDF (rebuild the xref table, etc.) without modifying its
#' content.
#'
#' @param doc A `pdfium_doc` from [pdf_open()] or [pdf_doc_new()].
#' @param file Destination path. The directory must exist.
#' @param incremental Logical. If `TRUE`, append an incremental
#'   update preserving the original byte layout (required for
#'   signed-PDF workflows). If `FALSE` (default), rewrite the
#'   whole file.
#' @param remove_security Logical. If `TRUE`, strip the
#'   encryption dictionary from the saved copy. Defaults `FALSE`.
#'   Use with caution.
#' @param subset_new_fonts Logical. If `TRUE` (default), subset
#'   newly-embedded fonts the same way Acrobat does. Set `FALSE`
#'   to embed full font tables.
#' @param version Integer or `NULL`. The PDF version in PDFium's
#'   "10 * major + minor" form (e.g. `17` for PDF 1.7). `NULL`
#'   (default) preserves the input file's declared version.
#' @return Invisibly returns `file`, the path written to.
#' @seealso [pdf_save_to_raw()] for in-memory output;
#'   [pdf_open()] for the read side; [pdf_doc_new()] for a fresh
#'   document.
#' @export
pdf_save <- function(doc, file, incremental = FALSE,
                     remove_security = FALSE,
                     subset_new_fonts = TRUE, version = NULL) {
  checkmate::assert_class(doc, "pdfium_doc")
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  checkmate::assert_string(file, min.chars = 1L)
  checkmate::assert_flag(incremental)
  checkmate::assert_flag(remove_security)
  checkmate::assert_flag(subset_new_fonts)
  checkmate::assert_int(version, null.ok = TRUE)

  flags <- encode_save_flags(incremental, remove_security,
                             subset_new_fonts)
  ver <- if (is.null(version)) -1L else as.integer(version)

  # Regenerate content on every page that was touched. Mutators
  # mark pages dirty by adding their R-side index to
  # `doc$dirty_pages`; pdf_save flushes the set here.
  flush_dirty_pages(doc)

  # Atomic-write: tempfile in the destination directory (so
  # file.rename is atomic on the same filesystem) → rename on
  # success.
  file <- path.expand(file)
  dest_dir <- dirname(file)
  if (!dir.exists(dest_dir)) {
    stop("Destination directory does not exist: ", dest_dir,
         call. = FALSE)
  }
  tmp <- tempfile(tmpdir = dest_dir, fileext = ".pdf.part")
  ok <- tryCatch(
    cpp_save_to_file(doc$ptr, tmp, flags, ver),
    # nocov start — `cpp_save_to_file` only raises when the
    # destination directory is unwritable, which we cover via the
    # `dir.exists(dest_dir)` check above. The tryCatch is defensive
    # against future C++ failure modes.
    error = function(e) {
      if (file.exists(tmp)) unlink(tmp)
      stop(e)
    }
    # nocov end
  )
  # nocov start — PDFium's FPDF_SaveAsCopy returns 0 only when the
  # FILEWRITE callback rejects bytes (i.e. our std::ofstream went
  # bad). The pre-flight `dir.exists` + tempfile pattern keeps that
  # path unreachable in the test suite.
  if (!isTRUE(ok)) {
    if (file.exists(tmp)) unlink(tmp)
    stop("PDFium failed to save the document.", call. = FALSE)
  }
  # nocov end
  if (!file.rename(tmp, file)) {
    # nocov start — file.rename can fail across filesystem
    # boundaries on some platforms; fall back to copy + unlink.
    # Same-fs guarantee from tempfile(tmpdir = dest_dir) makes this
    # unreachable in the suite.
    if (!file.copy(tmp, file, overwrite = TRUE)) {
      unlink(tmp)
      stop("Failed to move the saved PDF into place: ", file,
           call. = FALSE)
    }
    unlink(tmp)
    # nocov end
  }
  invisible(file)
}

#' Save a PDF document to a raw vector
#'
#' Like [pdf_save()] but returns the saved PDF's bytes as a `raw`
#' vector instead of writing to disk. Useful for piping the
#' serialised PDF directly into another consumer
#' (`httr2::req_body_raw()`, `aws.s3::put_object()`, etc.).
#'
#' @inheritParams pdf_save
#' @return A `raw` vector containing the saved PDF.
#' @seealso [pdf_save()] for disk output.
#' @export
pdf_save_to_raw <- function(doc, incremental = FALSE,
                            remove_security = FALSE,
                            subset_new_fonts = TRUE,
                            version = NULL) {
  checkmate::assert_class(doc, "pdfium_doc")
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  checkmate::assert_flag(incremental)
  checkmate::assert_flag(remove_security)
  checkmate::assert_flag(subset_new_fonts)
  checkmate::assert_int(version, null.ok = TRUE)

  flags <- encode_save_flags(incremental, remove_security,
                             subset_new_fonts)
  ver <- if (is.null(version)) -1L else as.integer(version)

  flush_dirty_pages(doc)
  cpp_save_to_raw(doc$ptr, flags, ver)
}

#' Create a new, empty PDF document
#'
#' Wraps `FPDF_CreateNewDocument`. The returned `pdfium_doc` has
#' no pages — add some with [pdf_page_new()] before saving.
#' Always returned with `readwrite = TRUE`; there is no read-only
#' new document.
#'
#' @return A `pdfium_doc` with zero pages.
#' @seealso [pdf_page_new()] to add a page;
#'   [pdf_save()] to persist the result.
#' @examples
#' doc <- pdf_doc_new()
#' pdf_page_new(doc, 1, 612, 792)
#' tmp <- tempfile(fileext = ".pdf")
#' pdf_save(doc, tmp)
#' pdf_close(doc)
#' @export
pdf_doc_new <- function() {
  ptr <- cpp_create_new_document()
  new_pdfium_doc(ptr, path = "<new>", readwrite = TRUE)
}

# Internal: flush dirty pages by calling FPDFPage_GenerateContent on
# each. Pages mark themselves dirty (via mark_page_dirty(doc, n)
# from mutator wrappers); pdf_save() invokes this just before
# serialising.
flush_dirty_pages <- function(doc) {
  state <- doc$state
  # nocov start — every `pdfium_doc` built via `new_pdfium_doc()`
  # has a non-NULL state env. The guard is defensive against future
  # construction paths that might forget to populate it.
  if (is.null(state)) return(invisible(NULL))
  # nocov end
  dirty <- state$dirty_pages
  if (length(dirty) == 0L) return(invisible(NULL))
  for (i in dirty) {
    page <- pdf_load_page(doc, i)
    cpp_page_generate_content(page$ptr)
    pdf_close_page(page)
  }
  # Reset the dirty set so a re-save (incremental or no-op) doesn't
  # double-flush. The state environment IS reference-semantics so
  # this update persists across function calls.
  state$dirty_pages <- integer(0L)
  invisible(NULL)
}

# Internal: append `page_num` to the doc's dirty-pages set. Mutators
# on a page (path setters, annotation setters, etc.) call this so
# pdf_save() can later call FPDFPage_GenerateContent before
# serialising. The state lives on a reference-semantics environment
# (see `new_pdfium_doc`) so the update is visible to callers.
mark_page_dirty <- function(doc, page_num) {
  state <- doc$state
  # nocov start — see flush_dirty_pages() for why this guard exists.
  if (is.null(state)) return(invisible(NULL))
  # nocov end
  state$dirty_pages <- unique(c(state$dirty_pages,
                                as.integer(page_num)))
  invisible(NULL)
}
