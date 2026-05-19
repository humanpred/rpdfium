# Page-level navigation extras: link-at-point hit testing and
# page additional-actions read.

# FPDF action-type codes used by both link readouts and the page
# additional-actions reader. Documented under fpdf_doc.h /
# fpdf_action.h.
.pdfium_action_types <- c(
  "goto", # 1 PDFACTION_GOTO  (within-document GoTo)
  "remote_goto", # 2 PDFACTION_REMOTEGOTO (other-document GoTo)
  "uri", # 3 PDFACTION_URI (web link)
  "launch", # 4 PDFACTION_LAUNCH (external file/program)
  "embedded_goto" # 5 PDFACTION_EMBEDDEDGOTO (into embedded file)
)
# 0 (PDFACTION_UNSUPPORTED) maps to "unsupported".

pdfium_action_type_name <- function(codes) {
  codes <- as.integer(codes)
  out <- rep("unsupported", length(codes))
  hit <- codes >= 1L & codes <= length(.pdfium_action_types)
  out[hit] <- .pdfium_action_types[codes[hit]]
  out
}

# FPDF dest-view codes (fpdf_doc.h):
#   0 = UNKNOWN_MODE, 1 = XYZ, 2 = FIT, 3 = FITH, 4 = FITV,
#   5 = FITR, 6 = FITB, 7 = FITBH, 8 = FITBV
.pdfium_dest_views <- c(
  "xyz", # 1 PDFDEST_VIEW_XYZ   (x, y, zoom; explicit point + scale)
  "fit", # 2 PDFDEST_VIEW_FIT   (fit whole page)
  "fith", # 3 PDFDEST_VIEW_FITH  (fit page width at y)
  "fitv", # 4 PDFDEST_VIEW_FITV  (fit page height at x)
  "fitr", # 5 PDFDEST_VIEW_FITR  (fit specific rectangle)
  "fitb", # 6 PDFDEST_VIEW_FITB  (fit bounding box)
  "fitbh", # 7 PDFDEST_VIEW_FITBH (fit bbox width at y)
  "fitbv" # 8 PDFDEST_VIEW_FITBV (fit bbox height at x)
)

pdfium_dest_view_name <- function(codes) {
  codes <- as.integer(codes)
  out <- rep("unknown", length(codes))
  hit <- codes >= 1L & codes <= length(.pdfium_dest_views)
  out[hit] <- .pdfium_dest_views[codes[hit]]
  out
}

#' Hit-test for the link annotation under a point
#'
#' Finds the link annotation at PDF user-space coordinates `(x, y)`
#' on a page. Useful for translating a click on a rendered PDF back
#' to its semantic target. Wraps `FPDFLink_GetLinkAtPoint` plus the
#' `FPDFLink_GetLinkZOrderAtPoint` / `FPDFLink_GetAction` /
#' `FPDFAction_*` family.
#'
#' Coordinates are in PDF user-space points (origin at the page's
#' bottom-left; page width and height in points come from
#' [pdf_page_size()]).
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc` (the page given by `page_num` will be loaded
#'   and closed internally).
#' @param x,y Point coordinates in PDF user-space points.
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @return A tibble with at most one row. Columns:
#'   * `z_order` — integer, the link's Z-order on the page
#'     (higher = on top).
#'   * `left`, `bottom`, `right`, `top` — link's rectangle in PDF
#'     points.
#'   * `action_type` — character: `"goto"`, `"remote_goto"`,
#'     `"uri"`, `"launch"`, `"embedded_goto"`, or `"unsupported"`.
#'   * `uri` — the link target URI when `action_type == "uri"`,
#'     `NA` otherwise.
#'   * `filepath` — the external file path when `action_type` is
#'     `"remote_goto"` / `"launch"` / `"embedded_goto"`, `NA`
#'     otherwise.
#'   * `dest_page` — the resolved 1-based target page for any GoTo
#'     action (`NA` if not resolvable).
#'
#'   Empty tibble (0 rows) when no link sits under the point.
#' @seealso [pdf_page_links()] for the full enumeration.
#' @export
pdf_link_at_point <- function(page, x, y, page_num = 1L) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    stop("`x` must be a single finite numeric.", call. = FALSE)
  }
  if (!is.numeric(y) || length(y) != 1L || !is.finite(y)) {
    stop("`y` must be a single finite numeric.", call. = FALSE)
  }
  ph <- as_open_page_pair(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  doc_ptr <- ph$page$doc$ptr
  raw <- cpp_link_at_point(
    doc_ptr, ph$page$ptr,
    as.numeric(x), as.numeric(y)
  )
  if (!raw$found) {
    return(empty_link_at_point_tibble())
  }
  tibble::tibble(
    z_order      = as.integer(raw$z_order),
    left         = raw$left,
    bottom       = raw$bottom,
    right        = raw$right,
    top          = raw$top,
    action_type  = pdfium_action_type_name(raw$action_code),
    uri          = if (nzchar(raw$uri)) raw$uri else NA_character_,
    filepath     = if (nzchar(raw$filepath)) raw$filepath else NA_character_,
    dest_page    = as.integer(raw$dest_page),
    dest_view    = pdfium_dest_view_name(raw$dest_view),
    dest_x       = raw$dest_x,
    dest_y       = raw$dest_y,
    dest_zoom    = raw$dest_zoom
  )
}

# Internal: empty-result tibble for pdf_link_at_point.
empty_link_at_point_tibble <- function() {
  tibble::tibble(
    z_order      = integer(),
    left         = numeric(),
    bottom       = numeric(),
    right        = numeric(),
    top          = numeric(),
    action_type  = character(),
    uri          = character(),
    filepath     = character(),
    dest_page    = integer(),
    dest_view    = character(),
    dest_x       = numeric(),
    dest_y       = numeric(),
    dest_zoom    = numeric()
  )
}

#' Page additional actions (open / close handlers)
#'
#' PDF pages can declare actions that fire when the page is opened
#' (`/AA/O`) or closed (`/AA/C`) — for example, to play a sound, run
#' JavaScript, or follow a URI. `pdf_page_actions()` enumerates
#' those actions for one page. Wraps `FPDF_GetPageAAction` plus the
#' `FPDFAction_*` accessors.
#'
#' Most PDFs don't declare page additional-actions; the typical
#' result is an empty tibble.
#'
#' @inheritParams pdf_link_at_point
#' @return A tibble with one row per defined additional-action.
#'   Columns:
#'   * `trigger` — `"open"` or `"close"`.
#'   * `action_type` — same vocabulary as
#'     [pdf_link_at_point()]'s `action_type`.
#'   * `uri`, `filepath`, `dest_page` — payload columns, same shape
#'     as in `pdf_link_at_point()`.
#' @export
pdf_page_actions <- function(page, page_num = 1L) {
  ph <- as_open_page_pair(page, page_num)
  on.exit(if (ph$close_on_exit) pdf_close_page(ph$page), add = TRUE)
  doc_ptr <- ph$page$doc$ptr
  raw <- cpp_page_aactions(doc_ptr, ph$page$ptr)
  n <- length(raw$trigger)
  if (n == 0L) {
    return(empty_page_actions_tibble())
  }
  uri <- ifelse(nzchar(raw$uri), raw$uri, NA_character_)
  fp <- ifelse(nzchar(raw$filepath), raw$filepath, NA_character_)
  tibble::tibble(
    trigger      = as.character(raw$trigger),
    action_type  = pdfium_action_type_name(raw$action_code),
    uri          = uri,
    filepath     = fp,
    dest_page    = as.integer(raw$dest_page),
    dest_view    = pdfium_dest_view_name(raw$dest_view),
    dest_x       = raw$dest_x,
    dest_y       = raw$dest_y,
    dest_zoom    = raw$dest_zoom
  )
}

empty_page_actions_tibble <- function() {
  tibble::tibble(
    trigger      = character(),
    action_type  = character(),
    uri          = character(),
    filepath     = character(),
    dest_page    = integer(),
    dest_view    = character(),
    dest_x       = numeric(),
    dest_y       = numeric(),
    dest_zoom    = numeric()
  )
}
