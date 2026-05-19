# Image page-object accessors. Each takes a `pdfium_obj` of type
# "image" (from pdf_page_objects()) and surfaces one facet of the
# embedded raster: metadata, the decoded pixel bitmap, the
# CTM-applied rendered bitmap, the raw embedded stream bytes, or the
# filter chain.

# PDFium FPDF_COLORSPACE_* values (from fpdf_edit.h). Index 1L is
# FPDF_COLORSPACE_UNKNOWN; we use it as the fallback when PDFium
# reports an unknown value.
.pdfium_colorspaces <- c(
  "Unknown", #  0
  "DeviceGray", #  1
  "DeviceRGB", #  2
  "DeviceCMYK", #  3
  "CalGray", #  4
  "CalRGB", #  5
  "Lab", #  6
  "ICCBased", #  7
  "Separation", #  8
  "DeviceN", #  9
  "Indexed", # 10
  "Pattern" # 11
)

# Internal: validate that x is a still-open pdfium_obj of type
# "image". Returns the obj unchanged on success.
check_image_obj <- function(obj, arg = "obj") {
  check_pdfium_obj(obj, allowed_types = "image", arg = arg)
}

#' Inspect metadata for an embedded image
#'
#' Reads dimensions, DPI, bits-per-pixel, and color space from a
#' `pdfium_obj` of type `"image"`. Wraps `FPDFImageObj_GetImageMetadata`
#' (plus `FPDFImageObj_GetImagePixelSize` for the pixel dims when
#' you only need width/height).
#'
#' @param obj A `pdfium_obj` of type `"image"`, typically returned by
#'   filtering [pdf_page_objects()] on `type == "image"`.
#' @return A named list with elements `width`, `height` (integer
#'   pixels), `horizontal_dpi`, `vertical_dpi` (numeric, may be 0
#'   when the image has no explicit DPI), `bits_per_pixel` (integer),
#'   `colorspace` (character; one of
#'   `r paste(sprintf('\"%s\"', .pdfium_colorspaces), collapse = ", ")`),
#'   and `marked_content_id` (integer; `-1` when absent).
#'
#' @seealso [pdf_image_bitmap()] for the decoded pixels,
#'   [pdf_image_rendered()] for the page-CTM-applied rendering,
#'   [pdf_image_data()] for the raw stream bytes.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "image.pdf",
#'   package = "pdfium"
#' )
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   page <- pdf_load_page(doc, 1L)
#'   imgs <- Filter(function(o) o$type == "image", pdf_page_objects(page))
#'   if (length(imgs) > 0L) pdf_image_info(imgs[[1L]])
#'   pdf_close_page(page)
#'   pdf_close(doc)
#' }
#' @export
pdf_image_info <- function(obj) {
  check_image_obj(obj)
  m <- cpp_image_metadata(obj$ptr, obj$page$ptr)
  cs_index <- m$colorspace + 1L
  # PDFium currently exposes 12 colorspace enum values (0..11). The
  # else-branch below fires only if PDFium adds new values above
  # index 11; unreachable today, hence # nocov on that line.
  cs_name <- if (cs_index >= 1L && cs_index <= length(.pdfium_colorspaces)) {
    .pdfium_colorspaces[[cs_index]]
  } else {
    "Unknown" # nocov
  }
  list(
    width             = as.integer(m$width),
    height            = as.integer(m$height),
    horizontal_dpi    = as.numeric(m$horizontal_dpi),
    vertical_dpi      = as.numeric(m$vertical_dpi),
    bits_per_pixel    = as.integer(m$bits_per_pixel),
    colorspace        = cs_name,
    marked_content_id = as.integer(m$marked_content_id)
  )
}

#' Pixel size of an embedded image
#'
#' Faster alternative to [pdf_image_info()] when only the
#' source-pixel dimensions are needed. Wraps
#' `FPDFImageObj_GetImagePixelSize`.
#'
#' @param obj A `pdfium_obj` of type `"image"`.
#' @return An integer vector with named elements `width` and
#'   `height`.
#' @seealso [pdf_image_info()] for the full metadata block.
#' @export
pdf_image_size <- function(obj) {
  check_image_obj(obj)
  sz <- cpp_image_pixel_size(obj$ptr)
  c(width = as.integer(sz[["width"]]), height = as.integer(sz[["height"]]))
}

#' Decoded image bitmap
#'
#' Returns the embedded image's decoded pixel buffer as a
#' [pdf_render_page()]-compatible `pdfium_bitmap`. Wraps
#' `FPDFImageObj_GetBitmap`, which decodes the source stream but does
#' not apply the page's coordinate transformation - the bitmap is the
#' raw source raster, oriented in the image's own coordinate system.
#'
#' @param obj A `pdfium_obj` of type `"image"`.
#' @return A `pdfium_bitmap` (integer matrix with class
#'   `c("pdfium_bitmap", "nativeRaster")`, `dim = c(height, width)`)
#'   carrying attributes `dpi = NA_real_` (the source image's DPI is
#'   in [pdf_image_info()] but doesn't apply to this raw raster),
#'   `source_page`, `source_path`, and `rotation_applied = 0L`. Use
#'   [as.array.pdfium_bitmap()] / [as.raster.pdfium_bitmap()] to
#'   convert to other shapes.
#'
#' @seealso [pdf_image_rendered()] for the CTM-applied rendering,
#'   [pdf_image_data()] for the raw embedded stream bytes.
#' @export
pdf_image_bitmap <- function(obj) {
  check_image_obj(obj)
  data <- cpp_image_get_bitmap(obj$ptr)
  attr(data, "channels") <- 4L
  new_pdfium_bitmap(
    data,
    dpi              = NA_real_,
    source_page      = obj$page$index,
    source_path      = obj$page$doc$path,
    rotation_applied = 0L
  )
}

#' Rendered image bitmap (page CTM applied)
#'
#' Returns the embedded image rasterised with its page-level
#' coordinate transformation applied. Wraps
#' `FPDFImageObj_GetRenderedBitmap`, which honors the image's matrix
#' and any mask. This is what a PDF viewer would draw for the image,
#' as opposed to [pdf_image_bitmap()] which gives the source raster
#' verbatim.
#'
#' @param obj A `pdfium_obj` of type `"image"`.
#' @return A `pdfium_bitmap`, same shape contract as
#'   [pdf_image_bitmap()].
#'
#' @seealso [pdf_image_bitmap()] for the source-pixel raster.
#' @export
pdf_image_rendered <- function(obj) {
  check_image_obj(obj)
  data <- cpp_image_get_rendered_bitmap(
    obj$page$doc$ptr,
    obj$page$ptr,
    obj$ptr
  )
  attr(data, "channels") <- 4L
  new_pdfium_bitmap(
    data,
    dpi              = NA_real_,
    source_page      = obj$page$index,
    source_path      = obj$page$doc$path,
    rotation_applied = 0L
  )
}

#' Raw bytes of an embedded image stream
#'
#' Returns the bytes that back the image object - either the
#' uncompressed pixel buffer (`decoded = TRUE`) or the raw embedded
#' stream as it sits in the PDF (`decoded = FALSE`). The raw form is
#' useful when you want to write the original JPEG / JBIG2 / JPEG2000
#' / Flate-deflated bitmap to disk without re-encoding; pair it with
#' [pdf_image_filters()] to know which decoders the PDF specifies.
#'
#' Wraps `FPDFImageObj_GetImageDataDecoded` or
#' `FPDFImageObj_GetImageDataRaw` (chosen by `decoded`).
#'
#' @param obj A `pdfium_obj` of type `"image"`.
#' @param decoded Logical scalar. `TRUE` (default) returns the
#'   decompressed pixel data after applying all filters; `FALSE`
#'   returns the stream bytes as stored.
#' @return A raw vector. Length is whatever PDFium reports - the
#'   filter-applied size for `decoded = TRUE`, the stored byte
#'   count for `decoded = FALSE`.
#' @seealso [pdf_image_filters()], [pdf_image_bitmap()].
#' @export
pdf_image_data <- function(obj, decoded = TRUE) {
  check_image_obj(obj)
  checkmate::assert_flag(decoded)
  cpp_image_data(obj$ptr, decoded)
}

#' Filter chain for an embedded image stream
#'
#' Returns the names of the filters PDFium applies, in order, to
#' decode the embedded image. Common values include
#' `"DCTDecode"` (JPEG), `"FlateDecode"` (Deflate), `"JBIG2Decode"`,
#' `"JPXDecode"` (JPEG 2000), `"CCITTFaxDecode"`, and
#' `"ASCII85Decode"`. Wraps `FPDFImageObj_GetImageFilterCount` plus
#' repeated `FPDFImageObj_GetImageFilter` calls.
#'
#' @param obj A `pdfium_obj` of type `"image"`.
#' @return A character vector. Empty when the image stream has no
#'   filters declared (e.g. uncompressed inline images).
#' @seealso [pdf_image_data()].
#' @export
pdf_image_filters <- function(obj) {
  check_image_obj(obj)
  cpp_image_filters(obj$ptr)
}

#' Decoded ICC color profile bytes for an embedded image
#'
#' Returns the raw bytes of the ICC color profile attached to the
#' image's colour space, if any. Useful for callers that need to
#' reproduce the colour rendering exactly (e.g. when re-encoding the
#' image outside PDFium). Wraps
#' `FPDFImageObj_GetIccProfileDataDecoded`.
#'
#' Most embedded images carry no ICC profile — they use a standard
#' colour space (`/DeviceRGB`, `/DeviceGray`, etc.). This function
#' returns `raw(0)` in that common case.
#'
#' @param obj A `pdfium_obj` of type `"image"`.
#' @return A `raw` vector. Length zero when the image has no ICC
#'   profile.
#' @export
pdf_image_icc_profile <- function(obj) {
  check_image_obj(obj)
  cpp_image_icc_profile(obj$ptr, obj$page$ptr)
}
