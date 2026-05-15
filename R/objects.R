#' Enumerate the objects on a page
#'
#' Returns a list of `pdfium_obj` handles - one per drawing primitive on
#' the page, in PDFium's z-order (back to front). Each element carries
#' its type ("path", "text", "image", "form", "shading", "unknown"),
#' a 1-based index within the page, and an internal pointer suitable
#' for passing to downstream object queries.
#'
#' Page objects do not own their own lifetime - they remain valid only
#' as long as the parent `pdfium_page` is open. The handle's internal
#' parent reference keeps the page (and transitively the document)
#' alive for as long as you hold the object, but calling
#' [pdf_close_page()] explicitly invalidates all returned objects.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a `pdfium_doc`
#'   (in which case the first page is loaded and closed automatically).
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A list (possibly empty) of `pdfium_obj` objects.
#'
#' @seealso [pdf_obj_type()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   objs <- pdf_page_objects(p)
#'   length(objs)
#'   vapply(objs, pdf_obj_type, character(1))
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_page_objects <- function(page, page_num = 1L) {
  page <- as_open_page(page, page_num)
  on_exit_close <- attr(page, ".close_on_exit")
  if (isTRUE(on_exit_close)) on.exit(pdf_close_page(page), add = TRUE)

  n <- cpp_page_object_count(page$ptr)
  out <- vector("list", n)
  for (i in seq_len(n)) {
    obj_ptr <- cpp_page_get_object(page$ptr, i - 1L)
    type_code <- cpp_obj_type(obj_ptr)
    type_name <- pdfium_obj_type_name(type_code)
    out[[i]] <- new_pdfium_obj(obj_ptr, page, i, type_name)
  }
  out
}

#' Report the type of a page object
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()].
#' @return Character scalar: one of `"path"`, `"text"`, `"image"`,
#'   `"form"`, `"shading"`, or `"unknown"`.
#' @export
pdf_obj_type <- function(obj) {
  if (!inherits(obj, "pdfium_obj")) {
    stop("`obj` must be a `pdfium_obj` (from `pdf_page_objects()`).",
         call. = FALSE)
  }
  if (!is_open(obj)) {
    stop("Parent page has been closed; object handle is no longer valid.",
         call. = FALSE)
  }
  # We cached the type at construction time. Verify against the live
  # query in case future PDFium versions allow runtime type mutation.
  pdfium_obj_type_name(cpp_obj_type(obj$ptr))
}

#' Axis-aligned bounding box of a page object
#'
#' Returns the smallest rectangle, in PDF point coordinates, that
#' contains all visible parts of `obj`. The bounds are in the page's
#' own coordinate system, i.e. origin at the bottom-left of the
#' un-rotated media box (matching `pdf_page_size()`). Note that the
#' bounds are not adjusted for the page's rotation; consult
#' [pdf_page_rotation()] when comparing positions across rotated
#' pages.
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()].
#' @return A named numeric vector with elements `left`, `bottom`,
#'   `right`, `top`. Width is `right - left`, height is `top - bottom`.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   objs <- pdf_page_objects(p)
#'   pdf_obj_bounds(objs[[1]])
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_obj_bounds <- function(obj) {
  if (!inherits(obj, "pdfium_obj")) {
    stop("`obj` must be a `pdfium_obj` (from `pdf_page_objects()`).",
         call. = FALSE)
  }
  if (!is_open(obj)) {
    stop("Parent page has been closed; object handle is no longer valid.",
         call. = FALSE)
  }
  cpp_obj_bounds(obj$ptr)
}

# Internal: convert a PDFium FPDF_PAGEOBJ_* code (int) to its short
# character name. Unknown codes return "unknown" to keep the public
# API stable against future PDFium enum additions.
pdfium_obj_type_name <- function(code) {
  idx <- as.integer(code) + 1L
  if (idx < 1L || idx > length(.pdfium_obj_type_names)) "unknown"
  else .pdfium_obj_type_names[[idx]]
}

# Internal: resolve a page argument that may be a pdfium_page or a
# pdfium_doc + page_num into an open page. When opened transparently
# from a doc, the returned page carries a `.close_on_exit = TRUE`
# attribute so the caller can close it on exit.
as_open_page <- function(x, page_num = 1L) {
  if (inherits(x, "pdfium_page")) {
    if (!is_open(x)) stop("Page has been closed.", call. = FALSE)
    attr(x, ".close_on_exit") <- FALSE
    return(x)
  }
  if (inherits(x, "pdfium_doc")) {
    p <- pdf_load_page(x, page_num)
    attr(p, ".close_on_exit") <- TRUE
    return(p)
  }
  stop("`page` must be a `pdfium_page` or `pdfium_doc`.", call. = FALSE)
}
