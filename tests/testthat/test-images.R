# Tests for the image-extraction API. Uses image.pdf - a 4x3in
# Cairo PDF whose only raster is a 16x16 RGB image with four solid
# coloured quadrants (TL=red, TR=green, BL=blue, BR=black) placed
# in a 2x2in box at PDF coords (1, 0.5)-(3, 2.5). Cairo embeds the
# raster as a FlateDecode-compressed RGB stream, so the test
# exercises the BGR-format path in bitmap_to_native_raster().

image_obj <- function(doc) {
  # First image-typed page object on page 1. Returns the obj plus
  # its parent page so the caller can defer-close both.
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  imgs <- Filter(function(o) identical(o$type, "image"), objs)
  if (length(imgs) == 0L) {
    pdf_page_close(page)
    testthat::skip("image.pdf fixture has no image objects")
  }
  list(obj = imgs[[1L]], page = page)
}

test_that("pdf_image_info returns the documented shape", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  info <- pdf_image_info(bundle$obj)
  expect_named(info, c(
    "width", "height", "horizontal_dpi", "vertical_dpi",
    "bits_per_pixel", "colorspace",
    "marked_content_id"
  ))
  expect_identical(info$width, 16L)
  expect_identical(info$height, 16L)
  expect_type(info$horizontal_dpi, "double")
  expect_type(info$vertical_dpi, "double")
  expect_identical(info$bits_per_pixel, 24L)
  expect_identical(info$colorspace, "DeviceRGB")
  expect_identical(info$marked_content_id, -1L)
})

test_that("pdf_image_size matches the source pixel dimensions", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  sz <- pdf_image_size(bundle$obj)
  expect_identical(sz, c(width = 16L, height = 16L))
})

test_that("pdf_image_bitmap returns a pdfium_bitmap with source dims", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  bmp <- pdf_image_bitmap(bundle$obj)
  expect_s3_class(bmp, c("pdfium_bitmap", "nativeRaster"), exact = TRUE)
  expect_equal(dim(bmp), c(16L, 16L))
  expect_identical(attr(bmp, "channels"), 4L)
  # DPI is NA for source-pixel bitmaps - the image's own DPI lives
  # in pdf_image_info() and doesn't apply to the raw source raster.
  expect_true(is.na(attr(bmp, "dpi")))
  expect_identical(attr(bmp, "source_page"), 1L)
  expect_identical(attr(bmp, "rotation_applied"), 0L)
})

test_that("pdf_image_bitmap pixel sampling matches the fixture's quadrants", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  arr <- as.array(pdf_image_bitmap(bundle$obj))
  # Sample interior of each 8x8 quadrant; expect ~exact colour since
  # Cairo embeds with no chroma subsampling.
  expect_equal(arr[2L, 2L, 1L:3L], c(1, 0, 0), tolerance = 0.02) # TL red
  expect_equal(arr[2L, 14L, 1L:3L], c(0, 1, 0), tolerance = 0.02) # TR green
  expect_equal(arr[14L, 2L, 1L:3L], c(0, 0, 1), tolerance = 0.02) # BL blue
  expect_equal(arr[14L, 14L, 1L:3L], c(0, 0, 0), tolerance = 0.02) # BR black
  # Alpha should be opaque everywhere (BGR source → A defaults to FF).
  expect_equal(arr[, , 4L], matrix(1, nrow = 16L, ncol = 16L))
})

test_that("pdf_image_bitmap is a conformant nativeRaster (writePNG(bmp) round-trips quadrants)", {
  # Regression guard for the historical stride-streak garble on
  # embedded-image bitmaps. pdf_image_bitmap() inherits nativeRaster,
  # so png::writePNG() reads its buffer row-major; a column-major
  # buffer would shear the 4 colour quadrants. Writing the raw object
  # and writing its as.array() decode must yield identical PNGs, and
  # the quadrants must survive the raw round-trip in the right corners.
  skip_if_not_installed("png")
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  bmp <- pdf_image_bitmap(bundle$obj)
  out_raw <- withr::local_tempfile(fileext = ".png")
  out_arr <- withr::local_tempfile(fileext = ".png")
  png::writePNG(bmp, out_raw)
  png::writePNG(as.array(bmp), out_arr)

  px_raw <- png::readPNG(out_raw)
  px_arr <- png::readPNG(out_arr)
  expect_equal(px_raw, px_arr) # identical: column-major would diverge
  # Quadrants land in the right corners through the raw path.
  expect_equal(px_raw[2L, 2L, 1L:3L], c(1, 0, 0), tolerance = 0.02) # TL red
  expect_equal(px_raw[2L, 14L, 1L:3L], c(0, 1, 0), tolerance = 0.02) # TR grn
  expect_equal(px_raw[14L, 2L, 1L:3L], c(0, 0, 1), tolerance = 0.02) # BL blu
  expect_equal(px_raw[14L, 14L, 1L:3L], c(0, 0, 0), tolerance = 0.02) # BR blk
})

test_that("pdf_image_rendered applies the page CTM", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  ren <- pdf_image_rendered(bundle$obj)
  expect_s3_class(ren, c("pdfium_bitmap", "nativeRaster"), exact = TRUE)
  # The image is placed in a 2x2in box on a 4x3in page. PDFium picks
  # a rendering resolution; exact dims are version-dependent but the
  # rendered bitmap must be larger than the 16x16 source.
  d <- dim(ren)
  expect_true(d[1L] > 16L)
  expect_true(d[2L] > 16L)
  expect_identical(attr(ren, "channels"), 4L)
})

test_that("pdf_image_data returns decoded vs raw stream bytes", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  decoded <- pdf_image_data(bundle$obj, decoded = TRUE)
  raw <- pdf_image_data(bundle$obj, decoded = FALSE)

  expect_type(decoded, "raw")
  expect_type(raw, "raw")
  # 16x16 pixels x 3 bytes/pixel (DeviceRGB, 24bpp).
  expect_length(decoded, 16L * 16L * 3L)
  # Raw FlateDecode-compressed stream must be strictly smaller than
  # the decoded form for this fixture (lots of solid-colour
  # repetition compresses well).
  expect_lt(length(raw), length(decoded))
})

test_that("pdf_image_filters reports the Flate filter chain", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  filters <- pdf_image_filters(bundle$obj)
  expect_type(filters, "character")
  expect_identical(filters, "FlateDecode")
})

test_that("pdf_image_icc_profile returns raw(0) when no ICC profile is set", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  out <- pdf_image_icc_profile(bundle$obj)
  expect_type(out, "raw")
  expect_equal(length(out), 0L)
})

test_that("image accessors reject non-image objects", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  paths <- Filter(function(o) identical(o$type, "path"), objs)
  skip_if(length(paths) == 0L, "shapes.pdf has no path objects")
  p <- paths[[1L]]

  expect_error(pdf_image_info(p), "Must be element of set")
  expect_error(pdf_image_size(p), "Must be element of set")
  expect_error(pdf_image_bitmap(p), "Must be element of set")
  expect_error(pdf_image_rendered(p), "Must be element of set")
  expect_error(pdf_image_data(p), "Must be element of set")
  expect_error(pdf_image_filters(p), "Must be element of set")
})

test_that("image accessors reject bad inputs", {
  expect_error(
    pdf_image_info("not-an-obj"),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_image_bitmap(list()),
    "class .pdfium_obj."
  )
  expect_error(
    pdf_image_data(42),
    "class .pdfium_obj."
  )
})

test_that("pdf_image_data validates the decoded flag", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bundle <- image_obj(doc)
  on.exit(pdf_page_close(bundle$page), add = TRUE, after = FALSE)

  expect_error(
    pdf_image_data(bundle$obj, decoded = NA),
    "Assertion on"
  )
  expect_error(
    pdf_image_data(bundle$obj, decoded = c(TRUE, FALSE)),
    "Assertion on"
  )
  expect_error(
    pdf_image_data(bundle$obj, decoded = "yes"),
    "Assertion on"
  )
})

test_that("image accessors refuse a closed parent page", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  imgs <- Filter(function(o) identical(o$type, "image"), objs)
  skip_if(length(imgs) == 0L, "image.pdf fixture has no images")
  img <- imgs[[1L]]
  pdf_page_close(page)

  expect_error(pdf_image_info(img), "Parent page has been closed")
  expect_error(pdf_image_bitmap(img), "Parent page has been closed")
  expect_error(pdf_image_rendered(img), "Parent page has been closed")
  expect_error(pdf_image_data(img), "Parent page has been closed")
  expect_error(pdf_image_filters(img), "Parent page has been closed")
  expect_error(pdf_image_size(img), "Parent page has been closed")
})

# ---- pdf_image_extract -----------------------------------------------------

test_that("pdf_image_extract writes a file with a chosen extension", {
  skip_if_not_installed("png")
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  imgs <- Filter(function(o) identical(o$type, "image"), objs)
  skip_if(length(imgs) == 0L, "image.pdf fixture has no images")
  img <- imgs[[1L]]

  tmp <- withr::local_tempfile()
  out <- pdf_image_extract(img, tmp)
  expect_true(file.exists(out))
  expect_true(file.size(out) > 0L)
  # Extension is one of the documented choices.
  expect_true(tools::file_ext(out) %in% c("jpg", "jp2", "png"))
})

test_that("pdf_image_extract picks .jpg for DCT-encoded streams", {
  # Construct a tiny image obj backed by JPEG bytes — that exercises
  # the DCTDecode branch of the dispatcher even when the shipped
  # `image.pdf` fixture happens to use FlateDecode.
  jp <- withr::local_tempfile(fileext = ".jpg")
  grDevices::jpeg(jp, width = 32, height = 32)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  graphics::rect(0, 0, 1, 1, col = "red", border = NA)
  grDevices::dev.off()

  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  img <- pdf_image_new(page, jp, bounds = c(0, 0, 50, 50))

  out <- pdf_image_extract(img, withr::local_tempfile())
  expect_match(out, "\\.jpg$")
  expect_true(file.exists(out))
  expect_true(file.size(out) > 0L)
})

test_that("pdf_image_extract rejects non-image objects", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  non_img <- Filter(function(o) !identical(o$type, "image"), objs)[[1L]]
  expect_error(pdf_image_extract(non_img, tempfile()),
                 "Must be element of set")
})

test_that("pdf_image_extract validates the path", {
  doc <- pdf_doc_open(fixture_path("image"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  imgs <- Filter(function(o) identical(o$type, "image"), objs)
  skip_if(length(imgs) == 0L, "image.pdf fixture has no images")
  img <- imgs[[1L]]
  expect_error(pdf_image_extract(img, ""), "Assertion on")
  expect_error(pdf_image_extract(img, NA_character_), "Assertion on")
  expect_error(pdf_image_extract(img, c("a", "b")), "Assertion on")
})
