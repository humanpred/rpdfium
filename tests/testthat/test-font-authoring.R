# Tests for font loading + custom-font text authoring:
#   * pdf_font_load_standard()  — wraps FPDFText_LoadStandardFont
#   * pdf_font_load()           — wraps FPDFText_LoadFont
#   * pdf_font_close()          — idempotent close
#   * pdf_text_new(..., font = handle)  — pdfium_font dispatch
#
# Standard-font tests run everywhere. TrueType tests skip when no
# system TTF can be located (Windows/macOS CI runners that don't ship
# DejaVu / Liberation, etc.).

# Helper: fresh doc + page, scheduled to close in the caller.
font_blank_page <- function(envir = parent.frame()) {
  doc <- pdf_doc_new()
  withr::defer(pdf_doc_close(doc), envir = envir)
  page <- pdf_page_new(doc, page_num = 1L, width = 612, height = 792)
  withr::defer(pdf_page_close(page), envir = envir,
                priority = "first")
  list(doc = doc, page = page)
}

# Helper: locate a system TrueType font path. Returns NULL when no
# candidate exists — tests gate themselves on this. Candidates
# cover Linux distros (Ubuntu / Debian / Alpine), macOS system
# fonts, and the Windows C:/Windows/Fonts directory.
find_system_ttf <- function() {
  candidates <- c(
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/Library/Fonts/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "C:/Windows/Fonts/arial.ttf"
  )
  for (p in candidates) {
    if (file.exists(p)) return(p)
  }
  NULL
}

# pdf_font_load_standard --------------------------------------------

test_that("pdf_font_load_standard returns a pdfium_font handle", {
  s <- font_blank_page()
  f <- pdf_font_load_standard(s$doc, "Helvetica")
  expect_s3_class(f, "pdfium_font")
  expect_true(pdfium:::is_open(f))
  expect_identical(f$name, "Helvetica")
})

test_that("pdf_font_load_standard accepts every standard font name", {
  s <- font_blank_page()
  for (nm in c("Helvetica-Bold", "Times-Italic", "Courier",
               "Symbol", "ZapfDingbats")) {
    f <- pdf_font_load_standard(s$doc, nm)
    expect_s3_class(f, "pdfium_font")
    expect_identical(f$name, nm)
  }
})

test_that("pdf_font_load_standard rejects non-standard names", {
  s <- font_blank_page()
  expect_error(pdf_font_load_standard(s$doc, "Comic Sans"),
               "Assertion on")
})

test_that("pdf_font_load_standard refuses a read-only doc", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_font_load_standard(doc, "Helvetica"),
               "readwrite")
})

# pdf_font_close ----------------------------------------------------

test_that("pdf_font_close releases the handle and is idempotent", {
  s <- font_blank_page()
  f <- pdf_font_load_standard(s$doc, "Helvetica")
  expect_true(pdfium:::is_open(f))
  pdf_font_close(f)
  expect_false(pdfium:::is_open(f))
  # Second call: no-op.
  expect_silent(pdf_font_close(f))
})

# pdf_text_new with a pdfium_font handle ----------------------------

test_that("pdf_text_new dispatches on pdfium_font handles", {
  s <- font_blank_page()
  f <- pdf_font_load_standard(s$doc, "Times-Bold")
  txt <- pdf_text_new(s$page, "Hi", font = f,
                       font_size = 14, x = 72, y = 720)
  expect_identical(txt$type, "text")
  expect_identical(pdf_text_content(txt), "Hi")
})

test_that("pdf_text_new rejects a closed pdfium_font handle", {
  s <- font_blank_page()
  f <- pdf_font_load_standard(s$doc, "Helvetica")
  pdf_font_close(f)
  expect_error(pdf_text_new(s$page, "x", font = f),
               "closed")
})

# pdf_font_load (TrueType) ------------------------------------------

test_that("pdf_font_load loads a TrueType font from a path", {
  ttf <- find_system_ttf()
  skip_if(is.null(ttf), "no system TrueType font available")
  s <- font_blank_page()
  f <- pdf_font_load(s$doc, ttf)
  expect_s3_class(f, "pdfium_font")
  expect_true(pdfium:::is_open(f))
})

test_that("pdf_font_load loads a TrueType font from raw bytes", {
  ttf <- find_system_ttf()
  skip_if(is.null(ttf), "no system TrueType font available")
  s <- font_blank_page()
  bytes <- readBin(ttf, what = "raw", n = file.info(ttf)$size)
  f <- pdf_font_load(s$doc, bytes)
  expect_s3_class(f, "pdfium_font")
})

test_that("pdf_font_load + pdf_text_new round-trips through pdf_save", {
  ttf <- find_system_ttf()
  skip_if(is.null(ttf), "no system TrueType font available")
  s <- font_blank_page()
  f <- pdf_font_load(s$doc, ttf)
  pdf_text_new(s$page, "Hello, world!",
                font = f, font_size = 18, x = 72, y = 720)
  out <- withr::local_tempfile(fileext = ".pdf")
  pdf_save(s$doc, out)

  doc2 <- pdf_doc_open(out)
  on.exit(pdf_doc_close(doc2), add = TRUE)
  page2 <- pdf_page_load(doc2, 1L)
  on.exit(pdf_page_close(page2), add = TRUE, after = FALSE)
  runs <- pdf_text_runs(page2)
  expect_true(any(grepl("Hello", runs$text, fixed = TRUE)))
})

test_that("pdf_font_load rejects an unreadable path", {
  s <- font_blank_page()
  expect_error(pdf_font_load(s$doc, tempfile(fileext = ".ttf")),
               "Font file not found")
})

test_that("pdf_font_load rejects unsupported font_data types", {
  s <- font_blank_page()
  expect_error(pdf_font_load(s$doc, 1L),
               "must be a raw vector")
})

test_that("pdf_font_load rejects garbage font bytes", {
  s <- font_blank_page()
  garbage <- as.raw(c(0x00, 0x01, 0x02, 0x03))
  expect_error(pdf_font_load(s$doc, garbage),
               "valid")
})

test_that("pdf_font_load refuses a read-only doc", {
  ttf <- find_system_ttf()
  skip_if(is.null(ttf), "no system TrueType font available")
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(pdf_font_load(doc, ttf),
               "readwrite")
})

test_that("pdf_font_load type argument is matched", {
  ttf <- find_system_ttf()
  skip_if(is.null(ttf), "no system TrueType font available")
  s <- font_blank_page()
  # Default ("truetype") works.
  f <- pdf_font_load(s$doc, ttf)
  expect_s3_class(f, "pdfium_font")
  # Bad type is rejected.
  expect_error(pdf_font_load(s$doc, ttf, type = "ttf"),
               "'arg' should be one of")
})

test_that("pdf_font_load validates cid flag", {
  ttf <- find_system_ttf()
  skip_if(is.null(ttf), "no system TrueType font available")
  s <- font_blank_page()
  expect_error(pdf_font_load(s$doc, ttf, cid = NA),
               "Assertion on")
  expect_error(pdf_font_load(s$doc, ttf, cid = "yes"),
               "Assertion on")
})

# pdfium_font format/print methods ----------------------------------

test_that("format.pdfium_font reflects open/closed state + name", {
  s <- font_blank_page()
  f <- pdf_font_load_standard(s$doc, "Helvetica")
  expect_match(format(f), "open")
  expect_match(format(f), "Helvetica")
  pdf_font_close(f)
  expect_match(format(f), "closed")
})

test_that("print.pdfium_font emits the formatted line", {
  s <- font_blank_page()
  f <- pdf_font_load_standard(s$doc, "Courier")
  expect_output(print(f), "pdfium_font")
  expect_output(print(f), "Courier")
})
