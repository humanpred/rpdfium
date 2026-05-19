#' Construct a `pdfium_doc` from an external pointer
#'
#' Internal helper. Wraps the `externalptr` returned by `cpp_open_document()`
#' in the S3 class hierarchy and stores the source path for display.
#'
#' @param ptr An `externalptr` to a PDFium `FPDF_DOCUMENT` handle.
#' @param path Character scalar — the source path the document was loaded from.
#' @return An object of class `c("pdfium_doc", "pdfium_handle")`.
#' @keywords internal
#' @noRd
new_pdfium_doc <- function(ptr, path) {
  stopifnot(typeof(ptr) == "externalptr", is.character(path), length(path) == 1L)
  structure(
    list(ptr = ptr, path = path),
    class = c("pdfium_doc", "pdfium_handle")
  )
}

#' Check whether a handle is still open
#'
#' Document and page handles check the underlying externalptr for
#' non-NULL. Page-object handles do not own their lifetime - they
#' live as long as their parent page - so for a `pdfium_obj` this
#' delegates to the parent page's open state.
#'
#' @param x A `pdfium_handle`.
#' @return `TRUE` if the underlying PDFium handle is still live,
#'   `FALSE` if the parent has been closed.
#' @keywords internal
#' @noRd
is_open <- function(x) {
  if (inherits(x, "pdfium_obj")) {
    return(is_open(x$page))
  }
  stopifnot(inherits(x, "pdfium_handle"))
  cpp_handle_is_valid(x$ptr)
}

#' @export
format.pdfium_doc <- function(x, ...) {
  state <- if (is_open(x)) "open" else "closed"
  sprintf("<pdfium_doc [%s] %s>", state, x$path)
}

#' @export
print.pdfium_doc <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

#' Construct a `pdfium_page` from an external pointer
#'
#' Internal helper. The page's externalptr carries its parent document's
#' externalptr in its `prot` slot, so the page keeps the doc alive for as
#' long as the page is reachable.
#'
#' @param ptr An `externalptr` to a PDFium `FPDF_PAGE` handle.
#' @param doc The parent `pdfium_doc` (kept on the R-list for printing
#'   and so the user can recover it).
#' @param index One-based page index (for display only).
#' @return An object of class `c("pdfium_page", "pdfium_handle")`.
#' @keywords internal
#' @noRd
new_pdfium_page <- function(ptr, doc, index) {
  stopifnot(
    typeof(ptr) == "externalptr",
    inherits(doc, "pdfium_doc"),
    is.numeric(index), length(index) == 1L
  )
  structure(
    list(ptr = ptr, doc = doc, index = as.integer(index)),
    class = c("pdfium_page", "pdfium_handle")
  )
}

#' @export
format.pdfium_page <- function(x, ...) {
  state <- if (is_open(x)) "open" else "closed"
  sprintf(
    "<pdfium_page [%s] page %d of %s>",
    state, x$index, basename(x$doc$path)
  )
}

#' @export
print.pdfium_page <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

# PDFium FPDFPageObj_GetType return values, indexed by code + 1L.
.pdfium_obj_type_names <- c(
  "unknown", # 0  FPDF_PAGEOBJ_UNKNOWN
  "text", # 1  FPDF_PAGEOBJ_TEXT
  "path", # 2  FPDF_PAGEOBJ_PATH
  "image", # 3  FPDF_PAGEOBJ_IMAGE
  "shading", # 4  FPDF_PAGEOBJ_SHADING
  "form" # 5  FPDF_PAGEOBJ_FORM
)

#' Construct a `pdfium_obj` from an external pointer
#'
#' Internal helper. Page objects do not own their own lifetime - they
#' point into the parent `pdfium_page`'s internal storage and become
#' dangling when the page closes. The externalptr's `prot` slot holds
#' the parent page's externalptr so R's GC cannot reclaim the page
#' while any object reference is live, but there is no finalizer on
#' the object itself.
#'
#' Nested objects (those inside a Form XObject, returned by
#' [pdf_form_objects()]) additionally carry a `parent_form` field
#' pointing back at the form's `pdfium_obj`. The form's own lifetime
#' is still bound to the page externalptr, so the lifetime model is
#' unchanged; `parent_form` is informational, used by
#' [format.pdfium_obj()] to render the containment chain.
#'
#' @param ptr An `externalptr` to a PDFium `FPDF_PAGEOBJECT`.
#' @param page The parent `pdfium_page`.
#' @param index One-based index within its container (page for
#'   top-level objects, form for nested objects).
#' @param type Character scalar - the object type (one of
#'   `.pdfium_obj_type_names`).
#' @param parent_form Optional `pdfium_obj` of type `"form"` - the
#'   form XObject this object is nested inside. `NULL` for top-level
#'   page objects.
#' @return An object of class `c("pdfium_obj", "pdfium_handle")`.
#' @keywords internal
#' @noRd
new_pdfium_obj <- function(ptr, page, index, type, parent_form = NULL) {
  stopifnot(
    typeof(ptr) == "externalptr",
    inherits(page, "pdfium_page"),
    is.numeric(index), length(index) == 1L,
    is.character(type), length(type) == 1L,
    is.null(parent_form) || inherits(parent_form, "pdfium_obj")
  )
  structure(
    list(
      ptr = ptr, page = page, index = as.integer(index), type = type,
      parent_form = parent_form
    ),
    class = c("pdfium_obj", "pdfium_handle")
  )
}

#' @export
format.pdfium_obj <- function(x, ...) {
  state <- if (is_open(x)) "open" else "closed"
  if (is.null(x$parent_form)) {
    sprintf(
      "<pdfium_obj [%s] %s, obj %d on page %d>",
      state, x$type, x$index, x$page$index
    )
  } else {
    sprintf(
      "<pdfium_obj [%s] %s, obj %d of form %d on page %d>",
      state, x$type, x$index, x$parent_form$index, x$page$index
    )
  }
}

#' @export
print.pdfium_obj <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}
