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
#' @param recursive Logical. When `TRUE`, descend into every
#'   `"form"` page object via [pdf_form_objects()] and return the
#'   flattened depth-first traversal: top-level objects first,
#'   then each form's nested objects immediately after the form,
#'   then any forms nested inside those, and so on. Nested
#'   objects carry the same `parent_form` slot that
#'   `pdf_form_objects()` would set, so callers can reconstruct
#'   the tree from the flat list. Default `FALSE`.
#' @return A list (possibly empty) of `pdfium_obj` objects.
#'
#' @seealso [pdf_obj_type()], [pdf_form_objects()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
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
pdf_page_objects <- function(page, page_num = 1L, recursive = FALSE) {
  checkmate::assert_flag(recursive)
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
  if (!recursive) {
    return(out)
  }
  flatten_page_objs_recursive(out)
}

# Internal: depth-first flatten that descends into form objects.
# Each visited form's children are inserted immediately after the
# form itself; the form remains in the output so callers can still
# query its matrix / bounds.
flatten_page_objs_recursive <- function(objs) {
  out <- list()
  for (o in objs) {
    out[[length(out) + 1L]] <- o
    if (identical(o$type, "form")) {
      nested <- pdf_form_objects(o)
      if (length(nested) > 0L) {
        out <- c(out, flatten_page_objs_recursive(nested))
      }
    }
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
  check_pdfium_obj(obj)
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
#'   package = "pdfium"
#' )
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
  check_pdfium_obj(obj)
  cpp_obj_bounds(obj$ptr)
}

#' Transformation matrix of a page object
#'
#' Returns the 2D affine transformation matrix attached to `obj`
#' as a 3-by-3 numeric matrix `M` in homogeneous form, so that a
#' point `(x, y)` in the object's local space maps to page-space
#' coordinates via `M %*% c(x, y, 1)`. The PDF convention stores
#' the six scalars `a`, `b`, `c`, `d`, `e`, `f`; this function
#' lifts them into the homogeneous-coordinate matrix
#'
#' ```
#'         | a c e |
#'   M  =  | b d f |
#'         | 0 0 1 |
#' ```
#'
#' so multiplication composes the way users expect (`M2 %*% M1`
#' applies `M1` first then `M2`). For paths drawn directly on a
#' page the matrix is usually the identity; text objects typically
#' carry a non-trivial matrix (Cairo for example places text at
#' font-size 1 and uses the matrix to scale and position the
#' glyphs).
#'
#' @param obj A `pdfium_obj` from [pdf_page_objects()] (any type).
#' @return A 3-by-3 numeric matrix. Use `M %*% c(x, y, 1)` to
#'   transform a point; the first two elements of the result are
#'   the transformed coordinates.
#'
#' @seealso [pdf_obj_bounds()], [pdf_path_segments()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   M <- pdf_obj_matrix(pdf_page_objects(p)[[1]])
#'   M %*% c(10, 20, 1)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_obj_matrix <- function(obj) {
  check_pdfium_obj(obj)
  m <- cpp_obj_matrix(obj$ptr)
  matrix(
    c(
      m[["a"]], m[["b"]], 0,
      m[["c"]], m[["d"]], 0,
      m[["e"]], m[["f"]], 1
    ),
    nrow = 3, ncol = 3, byrow = FALSE
  )
}

# Internal: convert a PDFium FPDF_PAGEOBJ_* code (int) to its short
# character name. Unknown codes return "unknown" to keep the public
# API stable against future PDFium enum additions.
pdfium_obj_type_name <- function(code) {
  idx <- as.integer(code) + 1L
  if (idx < 1L || idx > length(.pdfium_obj_type_names)) {
    "unknown"
  } else {
    .pdfium_obj_type_names[[idx]]
  }
}

# Internal: resolve a page argument that may be a pdfium_page or a
# pdfium_doc + page_num into an open page. When opened transparently
# from a doc, the returned page carries a `.close_on_exit = TRUE`
# attribute so the caller can close it on exit.
as_open_page <- function(x, page_num = 1L) {
  checkmate::assert_multi_class(
    x, c("pdfium_page", "pdfium_doc"),
    .var.name = "page"
  )
  if (inherits(x, "pdfium_page")) {
    if (!is_open(x)) stop("Page has been closed.", call. = FALSE)
    attr(x, ".close_on_exit") <- FALSE
    return(x)
  }
  # `x` is a pdfium_doc — load `page_num` and arrange for close.
  p <- pdf_load_page(x, page_num)
  attr(p, ".close_on_exit") <- TRUE
  p
}
