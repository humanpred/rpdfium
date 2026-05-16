#' pdfium: Idiomatic R Bindings to the PDFium PDF Engine
#'
#' Read PDF documents at the level of pages, page objects, and path geometry
#' using Google's PDFium engine. Surfaces path segments, stroke and fill style,
#' transformation matrices, text positions and content, font metadata, image
#' metadata, and page rendering.
#'
#' @section Where to start:
#'
#' Open a document with [pdf_open()] and inspect basic facts with
#' [pdf_page_count()]. Higher-level helpers (path extraction, text runs,
#' rendering) arrive in subsequent releases.
#'
#' @section Binary distribution:
#'
#' The underlying `libpdfium` shared library is downloaded from
#' [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
#' the first time the package is installed. The pinned version lives in
#' `tools/pdfium-version.txt`.
#'
#' @keywords internal
#' @name pdfium-package
#' @useDynLib pdfium, .registration = TRUE
#' @importFrom Rcpp sourceCpp
#' @importFrom grDevices as.raster
"_PACKAGE"
