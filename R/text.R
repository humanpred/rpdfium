#' Font size of a text page-object
#'
#' Returns the typographic ("em") font size, in PDF points, set on
#' the text object. This is the raw size stored in the PDF; it is
#' NOT scaled by the object's transformation matrix. PDF producers
#' often emit text at em-size `1` and let the CTM do the scaling
#' (Cairo's PDF backend works that way). To recover the on-page
#' rendered size, multiply this value by the y-scale of the
#' object's matrix (the matrix accessor lands in a later phase).
#'
#' @param obj A `pdfium_obj` of type `"text"` (from
#'   [pdf_page_objects()]).
#' @return Numeric scalar in PDF points, or `NA_real_` if PDFium
#'   reports no font size (rare; usually only for malformed PDFs).
#'
#' @seealso [pdf_page_objects()]
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   p <- pdf_load_page(doc, 1)
#'   text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(p))[[1]]
#'   pdf_text_font_size(text_obj)
#'   pdf_close_page(p)
#'   pdf_close(doc)
#' }
#' @export
pdf_text_font_size <- function(obj) {
  if (!inherits(obj, "pdfium_obj")) {
    stop("`obj` must be a `pdfium_obj` (from `pdf_page_objects()`).",
         call. = FALSE)
  }
  if (!is_open(obj)) {
    stop("Parent page has been closed; object handle is no longer valid.",
         call. = FALSE)
  }
  if (!identical(obj$type, "text")) {
    stop("`obj` must be a text-type pdfium_obj; got type \"",
         obj$type, "\".", call. = FALSE)
  }
  cpp_text_font_size(obj$ptr)
}
