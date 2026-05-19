# Form XObject accessor. PDF Form XObjects are reusable
# content-stream objects (a "sub-page" with its own page-object
# collection and a /Matrix). `pdf_form_objects()` mirrors
# `pdf_page_objects()` but enumerates the children of one form,
# returning fully-typed `pdfium_obj`s that participate in the same
# downstream API surface (`pdf_obj_bounds()`, `pdf_obj_matrix()`,
# `pdf_path_segments()`, `pdf_image_info()`, etc.).

#' List the page objects nested inside a Form XObject
#'
#' Wraps `FPDFFormObj_CountObjects` + `FPDFFormObj_GetObject` to
#' enumerate the page objects contained in a Form XObject. The
#' returned objects participate in the regular `pdfium_obj` API -
#' you can call [pdf_obj_type()], [pdf_obj_bounds()],
#' [pdf_obj_matrix()], and (per object type)
#' [pdf_path_segments()] / [pdf_image_info()] / [pdf_text_content()]
#' on each one. Nesting is recursive: a Form XObject may itself
#' contain other Form XObjects, and the returned `pdfium_obj`s of
#' type `"form"` can be passed back into `pdf_form_objects()`.
#'
#' Each returned object carries a `parent_form` slot pointing back
#' at `form`, used by the print/format methods to show the
#' containment path (`"obj 2 of form 1 on page 1"`). Lifetime is
#' bound to the parent page, not to the form: as long as the page
#' is open, the form and its nested objects remain valid.
#'
#' @param form A `pdfium_obj` of type `"form"`, typically obtained
#'   by filtering [pdf_page_objects()] (or another
#'   `pdf_form_objects()` call) on `type == "form"`.
#' @return A list of `pdfium_obj`s, one per nested page object.
#'   Empty list when the form has no children.
#'
#' @seealso [pdf_page_objects()] for the top-level enumeration,
#'   [pdf_obj_matrix()] for the form's own transformation matrix.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "form_xobject.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   page <- pdf_load_page(doc, 1L)
#'   forms <- Filter(function(o) o$type == "form", pdf_page_objects(page))
#'   if (length(forms) > 0L) {
#'     nested <- pdf_form_objects(forms[[1L]])
#'     length(nested)
#'   }
#'   pdf_close_page(page)
#'   pdf_close(doc)
#' }
#' @export
pdf_form_objects <- function(form) {
  check_pdfium_obj(form, allowed_types = "form", arg = "form")
  n <- cpp_form_object_count(form$ptr)
  if (n == 0L) {
    return(list())
  }

  lapply(seq_len(n), function(i) {
    inner <- cpp_form_get_object(form$ptr, form$page$ptr, i - 1L)
    type_int <- cpp_obj_type(inner)
    new_pdfium_obj(
      ptr         = inner,
      page        = form$page,
      index       = i,
      type        = pdfium_obj_type_name(type_int),
      parent_form = form
    )
  })
}
