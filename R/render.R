# PDFium render-flag bitmask. Combined as needed by pdf_render_page.
# Values copied from fpdfview.h:
.pdfium_render_flags <- c(
  annotations          = 0x01L,   # FPDF_ANNOT
  lcd_text             = 0x02L,   # FPDF_LCD_TEXT
  no_native_text       = 0x04L,   # FPDF_NO_NATIVETEXT
  grayscale            = 0x08L,   # FPDF_GRAYSCALE
  reverse_byte_order   = 0x10L,   # FPDF_REVERSE_BYTE_ORDER (we don't use)
  limit_image_cache    = 0x200L,  # FPDF_RENDER_LIMITEDIMAGECACHE
  force_halftone       = 0x400L,  # FPDF_RENDER_FORCEHALFTONE
  printing             = 0x800L,  # FPDF_PRINTING
  no_smooth_text       = 0x1000L, # FPDF_RENDER_NO_SMOOTHTEXT
  no_smooth_image      = 0x2000L, # FPDF_RENDER_NO_SMOOTHIMAGE
  no_smooth_path       = 0x4000L  # FPDF_RENDER_NO_SMOOTHPATH
)

#' Render a PDF page to a bitmap
#'
#' Rasterises one page of a PDF document via PDFium and returns a
#' `pdfium_bitmap` object (an integer matrix that inherits from base
#' R's `nativeRaster` class). Use [graphics::plot()] for an
#' immediate-display path (the S3 method here routes through
#' [grid::grid.raster()] on a 3-D RGBA array, the one R-engine
#' combination that renders pixel-for-pixel correctly across
#' platforms). Conversion helpers ([as.raster.pdfium_bitmap()],
#' [as.array.pdfium_bitmap()], [as.matrix.pdfium_bitmap()]) cover
#' the other common bitmap shapes downstream packages expect.
#'
#' @param page A `pdfium_page` from [pdf_load_page()], or a
#'   `pdfium_doc` (the page given by `page_num` will be loaded and
#'   closed internally).
#' @param page_num One-based page index. Only used when `page` is a
#'   `pdfium_doc`. Ignored otherwise.
#' @param dpi Render resolution in dots per inch (default `72`,
#'   meaning one pixel per PDF point). Higher values give larger,
#'   sharper output at proportional memory cost.
#' @param background Background color drawn behind the page content
#'   before rendering. Accepts any string [grDevices::col2rgb()]
#'   understands (named color, `"#RRGGBB"`, `"#RRGGBBAA"`), or `NA`
#'   for a fully transparent background. Defaults to `"white"`.
#' @param annotations Logical; render annotation appearance streams
#'   on top of the page content. Defaults to `FALSE`.
#' @param rotation Extra rotation in degrees applied on top of the
#'   page's own `/Rotate` attribute. One of `0`, `90`, `180`, `270`.
#'   Note: PDFium's rotation is clockwise; e.g. `90` means rotate
#'   the page 90° clockwise from its on-page orientation.
#' @return A `pdfium_bitmap` object - an integer matrix with `class
#'   = c("pdfium_bitmap", "nativeRaster")`, `dim = c(height, width)`,
#'   `channels = 4L`, plus attributes `dpi`, `source_page`,
#'   `rotation_applied`.
#'
#' @seealso [as.raster.pdfium_bitmap()],
#'   [as.array.pdfium_bitmap()] for output-shape conversions;
#'   [pdf_page_size()] and [pdf_page_rotation()] for the source
#'   page's dimensions.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   bmp <- pdf_render_page(pdf_open(fixture), dpi = 96)
#'   bmp                                # human summary
#'   if (interactive()) plot(bmp)       # render to the active device
#' }
#' @export
pdf_render_page <- function(page,
                            page_num = 1L,
                            dpi = 72,
                            background = "white",
                            annotations = FALSE,
                            rotation = 0L) {
  validate_render_args(dpi, annotations, rotation)
  rot_code <- switch(as.character(rotation),
                     "0" = 0L, "90" = 1L, "180" = 2L, "270" = 3L)

  page <- as_open_page(page, page_num)
  if (isTRUE(attr(page, ".close_on_exit"))) {
    on.exit(pdf_close_page(page), add = TRUE)
  }

  dims <- compute_render_pixels(page$ptr, dpi, rot_code)
  bg <- parse_bitmap_background(background)
  flags <- render_flags_bitmask(annotations)

  data <- cpp_render_page(
    page$ptr, dims$width, dims$height, rot_code, flags,
    background_argb = bg$argb,
    fill_background = bg$fill
  )
  attr(data, "channels") <- 4L
  new_pdfium_bitmap(
    data,
    dpi              = as.numeric(dpi),
    source_page      = page$index,
    source_path      = page$doc$path,
    rotation_applied = as.integer(rotation)
  )
}

#' Render a PDF page with an arbitrary affine transformation
#'
#' Power-user counterpart to [pdf_render_page()]. Instead of
#' choosing a DPI + rotation, the caller supplies a 3x2 affine
#' transformation matrix and the destination bitmap's pixel
#' dimensions, plus an optional clipping rectangle in PDF
#' user-space points. Useful for:
#'
#' * Rendering a cropped region of a page (set the matrix to scale
#'   + translate the desired region into the bitmap, plus a
#'   matching `clip_rect` to discard everything outside).
#' * Implementing zoom / pan in interactive viewers.
#' * Pre-warping for non-rectilinear projections (the matrix can
#'   include shear).
#'
#' Wraps `FPDF_RenderPageBitmapWithMatrix`.
#'
#' @section Matrix layout:
#'
#' `matrix` is a 3x2 numeric matrix (or a length-6 numeric vector)
#' representing the PDFium-order affine transformation
#' `(a, b, c, d, e, f)`, applied as:
#'
#' \deqn{x' = a\cdot x + c\cdot y + e}
#' \deqn{y' = b\cdot x + d\cdot y + f}
#'
#' For a simple scale, use `matrix(c(s, 0, 0, s, 0, 0), 3, 2,
#' byrow = TRUE)`. To crop to `(x0, y0)` -> `(x1, y1)` at scale
#' `s`, use `matrix(c(s, 0, 0, s, -s*x0, -s*y0), 3, 2, byrow =
#' TRUE)` plus `clip_rect = c(x0, y0, x1, y1)`.
#'
#' @inheritParams pdf_render_page
#' @param matrix Length-6 numeric vector (or 3x2 / 2x3 matrix
#'   coerced to length-6).
#' @param pixel_width,pixel_height Output bitmap dimensions in
#'   pixels (positive integers).
#' @param clip_rect Length-4 numeric `c(left, bottom, right, top)`
#'   in PDF user-space points, or `NULL` to skip clipping.
#' @return A `pdfium_bitmap`.
#' @seealso [pdf_render_page()] for the simpler dpi+rotation API.
#' @export
pdf_render_page_with_matrix <- function(page,
                                         matrix,
                                         pixel_width,
                                         pixel_height,
                                         clip_rect = NULL,
                                         page_num = 1L,
                                         background = "white",
                                         annotations = FALSE) {
  if (is.matrix(matrix)) {
    if (!all(dim(matrix) == c(3L, 2L)) &&
          !all(dim(matrix) == c(2L, 3L)) &&
          length(matrix) != 6L) {
      stop("`matrix` must be 3x2, 2x3, or a length-6 vector.",
           call. = FALSE)
    }
    matrix <- as.numeric(matrix)
  }
  if (!is.numeric(matrix) || length(matrix) != 6L ||
        any(!is.finite(matrix))) {
    stop("`matrix` must be a length-6 finite numeric vector.",
         call. = FALSE)
  }
  if (!is.numeric(pixel_width) || length(pixel_width) != 1L ||
        !is.finite(pixel_width) || pixel_width < 1L) {
    stop("`pixel_width` must be a single positive integer.",
         call. = FALSE)
  }
  if (!is.numeric(pixel_height) || length(pixel_height) != 1L ||
        !is.finite(pixel_height) || pixel_height < 1L) {
    stop("`pixel_height` must be a single positive integer.",
         call. = FALSE)
  }
  validate_render_annotations(annotations)
  clip_vec <- if (is.null(clip_rect)) numeric(0) else {
    if (!is.numeric(clip_rect) || length(clip_rect) != 4L) {
      stop("`clip_rect` must be NULL or a length-4 numeric vector ",
           "c(left, bottom, right, top).", call. = FALSE)
    }
    as.numeric(clip_rect)
  }

  page <- as_open_page(page, page_num)
  if (isTRUE(attr(page, ".close_on_exit"))) {
    on.exit(pdf_close_page(page), add = TRUE)
  }
  bg <- parse_bitmap_background(background)
  flags <- render_flags_bitmask(annotations)

  data <- cpp_render_page_with_matrix(
    page$ptr,
    as.integer(pixel_width), as.integer(pixel_height),
    as.numeric(matrix),
    clip_vec,
    render_flags     = flags,
    background_argb  = bg$argb,
    fill_background  = bg$fill
  )
  attr(data, "channels") <- 4L
  new_pdfium_bitmap(
    data,
    dpi              = NA_real_,  # matrix path has no single DPI
    source_page      = page$index,
    source_path      = page$doc$path,
    rotation_applied = 0L
  )
}

# Internal: input validation pulled out so pdf_render_page() stays
# under lintr's cyclocomp_linter limit. Each per-arg validator is
# itself simple enough to satisfy cyclocomp.
validate_render_args <- function(dpi, annotations, rotation) {
  validate_render_dpi(dpi)
  validate_render_annotations(annotations)
  validate_render_rotation(rotation)
  invisible(NULL)
}

validate_render_dpi <- function(dpi) {
  ok <- is.numeric(dpi) && length(dpi) == 1L && !is.na(dpi) && dpi > 0
  if (!ok) stop("`dpi` must be a single positive number.", call. = FALSE)
}

validate_render_annotations <- function(annotations) {
  ok <- is.logical(annotations) && length(annotations) == 1L &&
    !is.na(annotations)
  if (!ok) stop("`annotations` must be a single TRUE/FALSE.", call. = FALSE)
}

validate_render_rotation <- function(rotation) {
  ok <- is.numeric(rotation) && length(rotation) == 1L &&
    !is.na(rotation) && rotation %in% c(0, 90, 180, 270)
  if (!ok) {
    stop("`rotation` must be one of 0, 90, 180, or 270.", call. = FALSE)
  }
}

# Internal: page-size-in-points to bitmap dimensions, swapped for
# 90/270 rotations.
compute_render_pixels <- function(page_ptr, dpi, rot_code) {
  size_pt <- cpp_page_size(page_ptr)
  scale <- dpi / 72
  pixel_w <- as.integer(round(size_pt[["width"]]  * scale))
  pixel_h <- as.integer(round(size_pt[["height"]] * scale))
  if (rot_code %in% c(1L, 3L)) {
    list(width = pixel_h, height = pixel_w)
  } else {
    list(width = pixel_w, height = pixel_h)
  }
}

# Internal: render-flag bitmask from boolean toggles. Currently only
# annotations; placeholder for future flags (no_smooth_*, lcd_text,
# ...).
render_flags_bitmask <- function(annotations) {
  flags <- 0L
  if (isTRUE(annotations)) {
    flags <- bitwOr(flags, .pdfium_render_flags[["annotations"]])
  }
  flags
}

# Internal: convert a color spec to PDFium's 0xAARRGGBB int + a flag
# saying whether to fill at all (transparent backgrounds skip fill
# so the buffer remains zero / fully transparent).
parse_bitmap_background <- function(x) {
  if (length(x) == 1L && is.na(x)) {
    return(list(argb = 0L, fill = FALSE))
  }
  if (!is.character(x) && !is.numeric(x)) {
    stop("`background` must be a color string, integer, or NA.",
         call. = FALSE)
  }
  rgba <- grDevices::col2rgb(x, alpha = TRUE)[, 1L]
  argb <- bitwShiftL(as.integer(rgba[["alpha"]]), 24L) +
    bitwShiftL(as.integer(rgba[["red"]]),   16L) +
    bitwShiftL(as.integer(rgba[["green"]]),  8L) +
    as.integer(rgba[["blue"]])
  list(argb = argb, fill = TRUE)
}

# Internal constructor.
new_pdfium_bitmap <- function(data, dpi, source_page, source_path,
                              rotation_applied) {
  attr(data, "dpi")              <- dpi
  attr(data, "source_page")      <- source_page
  attr(data, "source_path")      <- source_path
  attr(data, "rotation_applied") <- rotation_applied
  class(data) <- c("pdfium_bitmap", "nativeRaster")
  data
}

#' @export
format.pdfium_bitmap <- function(x, ...) {
  # dim is (height, width); width is the second slot.
  d <- dim(x)
  sprintf(
    "<pdfium_bitmap %dx%d @ %g dpi, page %d of %s%s>",
    d[2L], d[1L],
    attr(x, "dpi"),
    attr(x, "source_page"),
    basename(attr(x, "source_path") %||% ""),
    if (identical(attr(x, "rotation_applied"), 0L)) {
      ""
    } else {
      sprintf(", rot %d", attr(x, "rotation_applied"))
    }
  )
}

#' @export
print.pdfium_bitmap <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

#' Plot a pdfium_bitmap
#'
#' Draws the bitmap into the active graphics device at its source
#' pixel resolution. Internally the bitmap is converted to a 3-D
#' numeric array (the format `png::writePNG()` and the R graphics
#' engine both consume cleanly) and drawn with [grid::grid.raster()]
#' on a fresh `grid` page.
#'
#' We go through `as.array(x)` rather than handing the integer matrix
#' directly to `graphics::rasterImage()` for two reasons that
#' compound:
#'
#' 1. Per the documented raster contract (see
#'    `?grDevices::as.raster`, "Raster images are internally
#'    represented row-first"), `"raster"` and `nativeRaster` objects
#'    must have row-major memory layout. R's `as.raster.matrix()`
#'    transposes its input precisely to satisfy that. Our integer
#'    matrix comes out of C++ as a standard R column-major matrix,
#'    so feeding it directly is non-conformant and shows diagonal
#'    stripe artifacts on detailed content.
#' 2. `rasterImage` with `plot.window` uses the user-coordinate
#'    system, which defaults (`xaxs = "r", yaxs = "r"`) to padding
#'    the interval by 4% on each side — silently compressing the
#'    raster into ~92% of the device and forcing sub-pixel
#'    resampling. `grid::grid.raster()` uses npc coordinates and
#'    isn't subject to this.
#'
#' Going through `as.array(x)` to a 3-D `c(H, W, 4)` numeric array
#' and rendering with `grid::grid.raster()` sidesteps both: the
#' array path uses positional channel storage (no row-vs-column
#' convention), and grid coordinates are 0..1 npc without padding.
#'
#' @param x A `pdfium_bitmap` from [pdf_render_page()] or
#'   [pdf_image_bitmap()] / [pdf_image_rendered()].
#' @param interpolate Passed through to [grid::grid.raster()].
#'   Default `TRUE`; set `FALSE` for pixel-exact (nearest-neighbour)
#'   display of small bitmaps.
#' @param ... Further arguments passed to [grid::grid.raster()].
#' @return Invisibly returns `x`. Called for the plotting side
#'   effect.
#' @exportS3Method graphics::plot pdfium_bitmap
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture) && interactive()) {
#'   bmp <- pdf_render_page(pdf_open(fixture), dpi = 96)
#'   plot(bmp)
#' }
plot.pdfium_bitmap <- function(x, interpolate = TRUE, ...) {
  grid::grid.newpage()
  grid::grid.raster(as.array(x), interpolate = interpolate, ...)
  invisible(x)
}

# Internal default-or-fallback helper (NULL-coalescing operator).
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Convert a pdfium_bitmap to base R's `"raster"` (character hex)
#'
#' Returns a character matrix of `"#RRGGBBAA"` strings - the shape
#' base R's `"raster"` class uses (and that
#' `grDevices::as.raster.matrix()` would produce on a hex-character
#' input). Note that R's nativeRaster integer encoding has no direct
#' `as.raster()` method; this converter does the byte-unpacking
#' explicitly.
#'
#' @param x A `pdfium_bitmap` from [pdf_render_page()].
#' @param ... Ignored.
#' @return A `"raster"` object (character matrix of hex colors).
#' @exportS3Method as.raster pdfium_bitmap
as.raster.pdfium_bitmap <- function(x, ...) {
  ints <- unclass(x)
  storage.mode(ints) <- "integer"
  # dim is (height, width); used as-is for outputs that share the
  # bitmap's row-major shape.
  d <- dim(ints)
  r <- bitwAnd(ints,                   0xFFL)
  g <- bitwAnd(bitwShiftR(ints,  8L),  0xFFL)
  b <- bitwAnd(bitwShiftR(ints, 16L),  0xFFL)
  a <- bitwAnd(bitwShiftR(ints, 24L),  0xFFL)
  hex <- sprintf("#%02X%02X%02X%02X", r, g, b, a)
  dim(hex) <- d
  class(hex) <- "raster"
  hex
}

#' Convert a pdfium_bitmap to a 3D RGBA array of doubles in 0..1
#'
#' Matches the format that [png::writePNG()] and `pdftools::pdf_render_page()`
#' both produce: a numeric array with dimensions `c(height, width, 4)`
#' and values in the closed interval 0 to 1.
#'
#' @param x A `pdfium_bitmap` from [pdf_render_page()].
#' @param ... Ignored.
#' @return A numeric array, dim `c(height, width, 4)`, channels
#'   ordered red, green, blue, alpha.
#' @exportS3Method as.array pdfium_bitmap
as.array.pdfium_bitmap <- function(x, ...) {
  ints <- unclass(x)
  storage.mode(ints) <- "integer"
  # dim is (height, width); used as-is for outputs that share the
  # bitmap's row-major shape.
  d <- dim(ints)
  r <- bitwAnd(ints,                   0xFFL)
  g <- bitwAnd(bitwShiftR(ints,  8L),  0xFFL)
  b <- bitwAnd(bitwShiftR(ints, 16L),  0xFFL)
  a <- bitwAnd(bitwShiftR(ints, 24L),  0xFFL)
  out <- array(NA_real_, dim = c(d[1L], d[2L], 4L))
  out[, , 1L] <- r / 255
  out[, , 2L] <- g / 255
  out[, , 3L] <- b / 255
  out[, , 4L] <- a / 255
  out
}

#' Convert a pdfium_bitmap to a hex-color matrix
#'
#' Alias for `as.raster(x)`, included for symmetry with R's other
#' raster classes.
#'
#' @param x A `pdfium_bitmap` from [pdf_render_page()].
#' @param ... Ignored.
#' @return A character matrix of `"#RRGGBBAA"` colors.
#' @exportS3Method as.matrix pdfium_bitmap
as.matrix.pdfium_bitmap <- function(x, ...) {
  unclass(as.raster.pdfium_bitmap(x, ...))
}

#' Render a PDF page directly to a PNG file
#'
#' Convenience wrapper that calls [pdf_render_page()] and writes the
#' result via [png::writePNG()]. The `png` package is required at
#' runtime (it's a Suggests dependency).
#'
#' @inheritParams pdf_render_page
#' @param file Output file path.
#' @return Invisibly returns `file`.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture) && requireNamespace("png", quietly = TRUE)) {
#'   out <- tempfile(fileext = ".png")
#'   pdf_render_to_png(pdf_open(fixture), file = out, dpi = 96)
#'   file.exists(out)
#' }
#' @export
pdf_render_to_png <- function(page, file, page_num = 1L, dpi = 72,
                              background = "white",
                              annotations = FALSE, rotation = 0L) {
  # Validate file first so callers see "file must be ..." even when
  # `png` isn't installed (e.g. R CMD check under
  # _R_CHECK_DEPENDS_ONLY_=TRUE).
  if (!is.character(file) || length(file) != 1L || is.na(file) ||
        !nzchar(file)) {
    stop("`file` must be a single non-empty character string.",
         call. = FALSE)
  }
  # nocov start - "png not installed" guard; coverage runs always
  # have png available because it's in Suggests and gets installed
  # for tests, so this branch is unreachable here. The behavior is
  # exercised manually and via R CMD check on stripped-down setups.
  if (!requireNamespace("png", quietly = TRUE)) {
    stop("`pdf_render_to_png()` requires the `png` package: ",
         "install.packages(\"png\")",
         call. = FALSE)
  }
  # nocov end
  bmp <- pdf_render_page(page, page_num = page_num, dpi = dpi,
                         background = background,
                         annotations = annotations,
                         rotation = rotation)
  png::writePNG(as.array(bmp), target = file)
  invisible(file)
}
