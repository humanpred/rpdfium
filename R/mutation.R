# Structural mutation: page rotation, deletion, reordering, merging,
# page-box assignment, document language. Each function takes a
# read-write `pdfium_doc` (or `pdfium_page`), asserts the
# readwrite flag, calls the matching PDFium one-liner, and returns
# the doc/page invisibly so edits can be chained with `|>`.

#' Set a page's rotation
#'
#' Wraps `FPDFPage_SetRotation`. Allowed values are `0`, `90`,
#' `180`, `270` degrees (clockwise). The PDF spec restricts page
#' rotation to multiples of 90; PDFium silently treats any other
#' value as 0.
#'
#' @param doc A read-write `pdfium_doc` from
#'   [pdf_open()] (with `readwrite = TRUE`) or [pdf_new_doc()].
#' @param page_num One-based page index.
#' @param degrees Integer; one of `0`, `90`, `180`, `270`.
#' @return Invisibly returns `doc` so the call can be chained.
#' @seealso [pdf_page_rotation()] for the read side.
#' @export
pdf_set_page_rotation <- function(doc, page_num, degrees) {
  assert_readwrite(doc)
  checkmate::assert_count(page_num, positive = TRUE)
  checkmate::assert_choice(degrees, c(0L, 90L, 180L, 270L))
  code <- as.integer(degrees / 90L)
  page <- pdf_load_page(doc, page_num)
  cpp_page_set_rotation(page$ptr, code)
  pdf_close_page(page)
  mark_page_dirty(doc, page_num)
  invisible(doc)
}

#' Delete a page
#'
#' Wraps `FPDFPage_Delete`. Removes the page at `page_num` from
#' the document. Subsequent page numbers shift down by one.
#'
#' @inheritParams pdf_set_page_rotation
#' @return Invisibly returns `doc`.
#' @export
pdf_delete_page <- function(doc, page_num) {
  assert_readwrite(doc)
  checkmate::assert_count(page_num, positive = TRUE)
  n <- cpp_page_count(doc$ptr)
  if (page_num > n) {
    stop(sprintf(
      "`page_num` (%d) exceeds the document's page count (%d).",
      page_num, n
    ), call. = FALSE)
  }
  cpp_page_delete(doc$ptr, as.integer(page_num - 1L))
  invisible(doc)
}

#' Reorder pages
#'
#' Wraps `FPDF_MovePages`. Moves a contiguous set of pages to a
#' new position within the document. The most common use is
#' rearranging a full document to a new order; pass a permutation
#' of `seq_len(pdf_page_count(doc))` as `new_order`.
#'
#' For partial reorderings (move pages 3–5 to position 1), pass
#' the source indices and the insertion point separately.
#'
#' @inheritParams pdf_set_page_rotation
#' @param new_order Integer vector. Either (a) a full permutation
#'   of `1:pdf_page_count(doc)` — the document is reordered in
#'   place to that permutation — or (b) the contiguous-move case
#'   handled via `move_pages` + `dest`.
#' @param move_pages Integer vector of 1-based source page
#'   indices to move (ignored when `new_order` is a full
#'   permutation).
#' @param dest One-based destination index for the moved pages
#'   (ignored when `new_order` is a full permutation).
#' @return Invisibly returns `doc`.
#' @export
pdf_reorder_pages <- function(doc, new_order = NULL,
                              move_pages = NULL, dest = NULL) {
  assert_readwrite(doc)
  n <- cpp_page_count(doc$ptr)
  if (!is.null(new_order)) {
    checkmate::assert_integerish(new_order, lower = 1L, upper = n,
                                 len = n, unique = TRUE,
                                 any.missing = FALSE)
    # FPDF_MovePages takes (source_indices, dest_index). To achieve
    # an arbitrary permutation we walk new_order left-to-right,
    # moving one source page at a time to its target position.
    new_order <- as.integer(new_order)
    for (target_idx in seq_along(new_order)) {
      src <- new_order[target_idx]
      # Translate the original 1-based index `src` to its current
      # 0-based position by tracking how many earlier indices have
      # already been moved ahead of it.
      moved_before <- sum(new_order[seq_len(target_idx - 1L)] < src)
      current_pos <- src - 1L + 0L  # 0-based
      cpp_move_pages(doc$ptr,
                     as.integer(current_pos - moved_before),
                     as.integer(target_idx - 1L))
    }
    return(invisible(doc))
  }
  checkmate::assert_integerish(move_pages, lower = 1L, upper = n,
                               any.missing = FALSE, min.len = 1L)
  checkmate::assert_count(dest, positive = TRUE)
  cpp_move_pages(doc$ptr,
                 as.integer(move_pages - 1L),
                 as.integer(dest - 1L))
  invisible(doc)
}

#' Merge documents into a new PDF
#'
#' Concatenates the pages of one or more source documents into a
#' fresh `pdfium_doc`, then saves to `file`. Wraps
#' `FPDF_CreateNewDocument` + `FPDF_ImportPagesByIndex` per source.
#'
#' Source documents are not modified. The returned doc has
#' `readwrite = TRUE`.
#'
#' @param docs A list of `pdfium_doc` objects, or a character
#'   vector of paths. Mixed lists are also accepted.
#' @param file Destination path. If `NULL` (default), the merged
#'   document is returned without saving.
#' @return When `file` is non-NULL, invisibly returns `file`. When
#'   `file` is NULL, returns the merged `pdfium_doc` open in
#'   memory.
#' @export
pdf_merge <- function(docs, file = NULL) {
  checkmate::assert_list(docs, min.len = 1L)
  checkmate::assert_string(file, min.chars = 1L, null.ok = TRUE)
  out <- pdf_new_doc()
  insert_at <- 0L
  for (entry in docs) {
    if (is.character(entry)) {
      src <- pdf_open(entry)
    } else {
      checkmate::assert_class(entry, "pdfium_doc")
      src <- entry
    }
    n <- cpp_page_count(src$ptr)
    cpp_import_pages_by_index(out$ptr, src$ptr,
                              seq_len(n) - 1L, insert_at)
    insert_at <- insert_at + n
    if (is.character(entry)) pdf_close(src)
  }
  if (is.null(file)) {
    return(out)
  }
  pdf_save(out, file)
  pdf_close(out)
  invisible(file)
}

#' Combine N pages of a document into one
#'
#' Wraps `FPDF_ImportNPagesToOne` — imposition / N-up imposition.
#' Pages are arranged into a `cols x rows` grid on each output
#' page; if the source has more pages than fit on one output
#' page, more output pages are created.
#'
#' @inheritParams pdf_set_page_rotation
#' @param file Destination path.
#' @param cols,rows Grid dimensions per output page.
#' @param output_width,output_height Output page size in PDF
#'   points. Defaults to US Letter (612 x 792).
#' @return Invisibly returns `file`.
#' @export
pdf_n_up <- function(doc, file, cols, rows,
                     output_width = 612, output_height = 792) {
  checkmate::assert_class(doc, "pdfium_doc")
  checkmate::assert_string(file, min.chars = 1L)
  checkmate::assert_count(cols, positive = TRUE)
  checkmate::assert_count(rows, positive = TRUE)
  checkmate::assert_number(output_width, lower = 1)
  checkmate::assert_number(output_height, lower = 1)
  out_ptr <- cpp_import_n_pages_to_one(doc$ptr,
                                       as.numeric(output_width),
                                       as.numeric(output_height),
                                       as.integer(cols),
                                       as.integer(rows))
  out <- new_pdfium_doc(out_ptr, "<n_up>", readwrite = TRUE)
  pdf_save(out, file)
  pdf_close(out)
  invisible(file)
}

#' Add a new blank page
#'
#' Wraps `FPDFPage_New`. Inserts a new blank page of the given
#' dimensions at `page_num` (1-based). Existing pages at or above
#' `page_num` shift down by one.
#'
#' @inheritParams pdf_set_page_rotation
#' @param page_num Insertion index, 1-based. Must satisfy
#'   `1 <= page_num <= pdf_page_count(doc) + 1`.
#' @param width,height Page size in PDF points (1 pt = 1/72 in).
#'   US Letter is `612, 792`; A4 is `595, 842`.
#' @return A `pdfium_page` handle for the new page. (Unlike
#'   most mutators this returns a page rather than the doc,
#'   because callers typically want to add content to the page
#'   immediately.)
#' @export
pdf_new_page <- function(doc, page_num, width, height) {
  assert_readwrite(doc)
  n <- cpp_page_count(doc$ptr)
  checkmate::assert_int(page_num, lower = 1L, upper = n + 1L)
  checkmate::assert_number(width, lower = 1)
  checkmate::assert_number(height, lower = 1)
  ptr <- cpp_page_new(doc$ptr, as.integer(page_num - 1L),
                      as.numeric(width), as.numeric(height))
  new_pdfium_page(ptr, doc, page_num)
}

#' Set one of a page's named bounding boxes
#'
#' Wraps `FPDFPage_Set{Media,Crop,Bleed,Trim,Art}Box`. Companion to
#' [pdf_page_box()].
#'
#' @inheritParams pdf_set_page_rotation
#' @param box One of `"media"`, `"crop"`, `"bleed"`, `"trim"`,
#'   `"art"`.
#' @param rect Length-4 numeric `c(left, bottom, right, top)` in
#'   PDF user-space points.
#' @return Invisibly returns `doc`.
#' @seealso [pdf_page_box()] for the read side.
#' @export
pdf_set_page_box <- function(doc, page_num,
                             box = c("media", "crop", "bleed",
                                     "trim", "art"),
                             rect) {
  assert_readwrite(doc)
  checkmate::assert_count(page_num, positive = TRUE)
  box <- match.arg(box)
  checkmate::assert_numeric(rect, len = 4L, finite = TRUE,
                            any.missing = FALSE)
  page <- pdf_load_page(doc, page_num)
  cpp_page_set_box(page$ptr, box,
                   as.numeric(rect[1L]), as.numeric(rect[2L]),
                   as.numeric(rect[3L]), as.numeric(rect[4L]))
  pdf_close_page(page)
  invisible(doc)
}

#' Set the document's declared language
#'
#' Wraps `FPDFCatalog_SetLanguage`. The language tag follows BCP-47
#' (e.g. `"en"`, `"en-US"`, `"de-AT"`).
#'
#' @inheritParams pdf_set_page_rotation
#' @param lang Character scalar — the BCP-47 language tag.
#' @return Invisibly returns `doc`.
#' @export
pdf_set_doc_language <- function(doc, lang) {
  assert_readwrite(doc)
  checkmate::assert_string(lang, min.chars = 1L)
  if (!cpp_catalog_set_language(doc$ptr, enc2utf8(lang))) {
    stop("FPDFCatalog_SetLanguage returned failure.", call. = FALSE)
  }
  invisible(doc)
}
