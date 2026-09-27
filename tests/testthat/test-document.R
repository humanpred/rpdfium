test_that("pdf_doc_open() rejects bad inputs before touching PDFium", {
  expect_error(
    pdf_doc_open(NULL),
    "One of `path` or `source` must be provided"
  )
  expect_error(pdf_doc_open(character()), "Assertion on")
  expect_error(pdf_doc_open(NA_character_), "Assertion on")
  expect_error(pdf_doc_open(""), "Assertion on")
  expect_error(pdf_doc_open("/no/such/file.pdf"), "PDF file not found")
})

test_that("pdf_doc_open() validates the password argument", {
  pdf <- fixture_path("minimal")
  expect_error(pdf_doc_open(pdf, password = 1), "Assertion on")
  expect_error(pdf_doc_open(pdf, password = NA_character_), "Assertion on")
  expect_error(pdf_doc_open(pdf, password = c("a", "b")), "Assertion on")
  doc <- pdf_doc_open(pdf, password = NULL)
  expect_s3_class(doc, "pdfium_doc")
  pdf_doc_close(doc)
})

test_that("pdf_page_count() can take a path or an open doc", {
  pdf <- fixture_path("minimal")
  expect_equal(pdf_page_count(pdf), 1L)

  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_s3_class(doc, "pdfium_doc")
  expect_equal(pdf_page_count(doc), 1L)
})

test_that("pdf_doc_close() is idempotent and blocks further work", {
  pdf <- fixture_path("minimal")
  doc <- pdf_doc_open(pdf)
  expect_invisible(pdf_doc_close(doc))
  expect_invisible(pdf_doc_close(doc))
  expect_error(pdf_page_count(doc), "closed")
})

test_that("pdf_doc_close() refuses non-doc inputs", {
  expect_error(
    pdf_doc_close("not a doc"),
    "class .pdfium_doc."
  )
  expect_error(
    pdf_doc_close(NULL),
    "class .pdfium_doc."
  )
})

test_that("pdf_page_count() rejects non-doc inputs cleanly", {
  expect_error(
    pdf_page_count(42),
    "class .pdfium_doc."
  )
})

test_that("print() and format() reflect open / closed state", {
  pdf <- fixture_path("minimal")
  doc <- pdf_doc_open(pdf)
  on.exit(try(pdf_doc_close(doc), silent = TRUE), add = TRUE)
  expect_match(format(doc), "open")
  pdf_doc_close(doc)
  expect_match(format(doc), "closed")
  expect_output(print(doc), "closed")
})

test_that("auto-finalizer releases handles dropped without explicit close", {
  pdf <- fixture_path("minimal")
  open_and_drop <- function() {
    d <- pdf_doc_open(pdf)
    invisible(pdf_page_count(d))
  }
  for (i in seq_len(100)) {
    open_and_drop()
  }
  invisible(gc(verbose = FALSE))
  succeed()
})

# URL paths --------------------------------------------------------
# The `path =` argument auto-detects URLs (anything matching the RFC
# 3986 scheme://host shape) and routes them through base::url() +
# readBin() before handing the bytes to PDFium's in-memory loader.
# We don't maintain a scheme allowlist — whatever R's url() handles
# is what we handle.

test_that("pdf_doc_open accepts a file:// URL", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_s3_class(doc, "pdfium_doc")
  expect_identical(pdf_page_count(doc), 1L)
})

test_that("pdf_doc_open stores the URL as the doc path", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(doc$path, url)
})

test_that("pdf_doc_open passes URL bytes through to readwrite mode", {
  url <- paste0("file://", fixture_path("minimal"))
  doc <- pdf_doc_open(url, readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_true(doc$readwrite)
})

test_that("pdf_doc_open surfaces base::url() errors on unreachable hosts", {
  # base::url() emits a warning then errors when the host is
  # unreachable; we suppress the warning to keep the test output
  # clean but assert the error still propagates.
  suppressWarnings(
    expect_error(pdf_doc_open("https://example.invalid/x.pdf"))
  )
})

test_that("pdf_doc_open treats non-URL strings as local paths", {
  # A string with a colon but no `://` is a path on this system,
  # not a URL — should not trigger url() handling.
  expect_error(pdf_doc_open("foo:bar"), "PDF file not found")
})

test_that("looks_like_url accepts every RFC 3986 scheme shape", {
  for (u in c("http://x", "https://x", "ftp://x", "file:///x",
              "FILE:///x", "git+ssh://x")) {
    expect_true(pdfium:::looks_like_url(u), info = u)
  }
  for (nu in c("/absolute/path", "relative/path", "x.pdf",
               "1http://no", NA_character_, c("a", "b"), 42L, NULL)) {
    expect_false(pdfium:::looks_like_url(nu),
                 info = deparse(nu, control = NULL))
  }
})

test_that("pdf_doc_open's URL path round-trips through pdf_doc_summary", {
  url <- paste0("file://", fixture_path("annotated"))
  doc <- pdf_doc_open(url)
  on.exit(pdf_doc_close(doc), add = TRUE)
  s <- pdf_doc_summary(doc)
  expect_identical(s$path, url)
  expect_gt(s$form_field_count, 0L)
})

# init.cpp surface ----------------------------------------------------

test_that("cpp_open_document errors on a non-PDF file", {
  # FPDF_LoadDocument returns NULL when the file isn't a recognisable
  # PDF. Hit the cpp_open_document NULL branch with a text file.
  txt <- withr::local_tempfile(fileext = ".pdf")
  writeLines("not a pdf", txt)
  expect_error(pdf_doc_open(txt), "Failed to load PDF")
})

test_that("cpp_open_document_from_memory errors on garbage bytes", {
  # FPDF_LoadMemDocument64 returns NULL for non-PDF buffers; the
  # shim must free the heap copy and surface the PDFium error code.
  garbage <- as.raw(c(0x00, 0x01, 0x02, 0x03, 0x04))
  expect_error(
    pdf_doc_open(source = garbage),
    "Failed to load PDF from memory"
  )
})

test_that("cpp_destroy_library + reopen survives a round-trip", {
  # Drive the .onUnload code path mid-process by destroying and
  # re-initialising the library, then verify a fresh document opens.
  # All previously-open docs in this test must be closed first.
  pdfium:::cpp_destroy_library()
  # Idempotent: a second destroy is a no-op.
  pdfium:::cpp_destroy_library()
  # Open auto-reinits via the g_library_initialised flag in init.cpp.
  doc <- pdf_doc_open(fixture_path("minimal"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(pdf_page_count(doc), 1L)
})

test_that("the default system-font provider survives a library round-trip", {
  # Finalize documents from earlier tests while the library that
  # opened them is still alive.
  invisible(gc())
  expect_identical(pdf_system_fonts_install_default(), TRUE)
  # Destroying the library frees the provider; installing again
  # re-initialises the library and installs a new one.
  pdfium:::cpp_destroy_library()
  expect_identical(pdf_system_fonts_install_default(), TRUE)
  expect_identical(pdf_system_fonts_install_default(), TRUE)
  # A font that is not embedded is substituted through the font
  # mapper, which consults the installed provider.
  bytes <- inline_pdf_bytes(c(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    paste0(
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 60] ",
      "/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>"
    ),
    inline_pdf_stream("", "BT /F1 36 Tf 10 15 Td (Hello) Tj ET"),
    "<< /Type /Font /Subtype /TrueType /BaseFont /DejaVuSans >>"
  ))
  doc <- pdf_doc_open(source = bytes)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  text_obj <- pdf_page_objects(page)[[1L]]
  expect_false(pdf_text_font(text_obj)$font_is_embedded)
  expect_true(any(as.raster(pdf_render_page(page)) != "#FFFFFFFF"))
})

# pdf_doc_close() and the document's pages (ADR-025) ---------------
#
# PDFium expects every page to be closed before its document. Closing
# a document therefore closes the pages still open on it first, after
# their annotation handles (ADR-024). Calls on those pages, and on
# page-objects read from them, then raise an error instead of reading
# the freed document.

doc_close_page_msg <- "^Page has been closed: its document was closed\\.$"
doc_close_obj_msg <- paste0(
  "^Parent page has been closed: its document was closed\\. ",
  "The object handle is no longer valid\\.$"
)
no_handles <- c(annot = 0L, page = 0L, font = 0L, xobject = 0L)

test_that("pdf_doc_close() closes the document's pages", {
  doc <- pdf_doc_open(fixture_path("unicode"))
  page <- pdf_page_load(doc, 1L)
  again <- pdf_page_load(doc, 1L)
  expect_identical(
    pdfium:::cpp_doc_handle_counts(doc$ptr),
    c(annot = 0L, page = 2L, font = 0L, xobject = 0L)
  )
  pdf_doc_close(doc)
  expect_identical(pdfium:::cpp_doc_handle_counts(doc$ptr), no_handles)
  for (p in list(page, again)) {
    expect_false(is_open(p))
    expect_false(pdfium:::cpp_handle_is_valid(p$ptr))
    expect_identical(
      format(p), "<pdfium_page [closed] page 1 of unicode.pdf>"
    )
  }
  expect_error(pdf_render_page(page), doc_close_page_msg)
  expect_error(pdf_text_runs(page), doc_close_page_msg)
  expect_error(pdf_page_objects(page), doc_close_page_msg)
  expect_error(pdf_page_size(page), doc_close_page_msg)
  expect_error(pdf_page_rotation(page), doc_close_page_msg)
  expect_error(summary(page), doc_close_page_msg)
  expect_error(pdf_page_has_transparency(page), doc_close_page_msg)
  # The C++ layer refuses the cleared page as well.
  expect_error(pdfium:::cpp_page_size(page$ptr), "^Page handle is closed\\.$")
  expect_error(
    pdfium:::cpp_page_text_runs(page$ptr),
    "^Page handle is NULL \\(closed\\?\\)\\.$"
  )
  # A page closed by hand before its document keeps the plain message.
  doc <- pdf_doc_open(fixture_path("unicode"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  pdf_page_close(page)
  expect_error(pdf_page_size(page), "^Page has been closed\\.$")
})

test_that("pdf_page_close() on a page its document closed is a no-op", {
  doc <- pdf_doc_open(fixture_path("unicode"))
  page <- pdf_page_load(doc, 1L)
  pdf_doc_close(doc)
  expect_invisible(pdf_page_close(page))
  expect_false(is_open(page))
  expect_identical(doc$state$open_pages, setNames(list(), character()))
})

test_that("page-objects read before pdf_doc_close() are refused after it", {
  doc <- pdf_doc_open(fixture_path("unicode"))
  objs <- pdf_page_objects(pdf_page_load(doc, 1L))
  form_doc <- pdf_doc_open(fixture_path("form_xobject"))
  forms <- pdf_page_objects(pdf_page_load(form_doc, 1L))
  nested <- pdf_form_objects(forms[[1L]])
  # Objects in an annotation's appearance stream, and the children of a
  # form among them, pin the annotation rather than the page.
  ap_doc <- pdf_doc_open(source = inline_annot_objects_pdf())
  stamp <- pdf_annotations(pdf_page_load(ap_doc, 1L))[[1L]]
  in_annot <- pdf_annot_objects(stamp)
  in_annot_form <- pdf_form_objects(in_annot[[5L]])
  expect_identical(
    vapply(objs, function(o) o$type, character(1L)),
    c("path", "text", "text", "text", "text", "text")
  )
  expect_length(nested, 2L)
  expect_identical(
    vapply(in_annot, function(o) o$type, character(1L)),
    c("path", "text", "image", "shading", "form")
  )
  expect_length(in_annot_form, 1L)
  handles <- c(objs, nested, in_annot, in_annot_form)
  expect_identical(vapply(handles, is_open, logical(1L)), rep(TRUE, 14L))
  pdf_doc_close(doc)
  pdf_doc_close(form_doc)
  pdf_doc_close(ap_doc)
  expect_identical(vapply(handles, is_open, logical(1L)), rep(FALSE, 14L))
  for (obj in handles) {
    expect_error(pdf_obj_bounds(obj), doc_close_obj_msg)
    expect_error(pdf_obj_matrix(obj), doc_close_obj_msg)
    # The C++ layer refuses them too: each pins its closed page or,
    # for an annotation's objects, its closed annotation.
    expect_error(
      pdfium:::cpp_obj_bounds(obj$ptr),
      "^Page-object handle's parent has been closed"
    )
  }
  expect_error(pdf_text_content(objs[[2L]]), doc_close_obj_msg)
  expect_error(pdf_path_segments(nested[[1L]]), doc_close_obj_msg)
  expect_error(pdf_form_objects(in_annot[[5L]]), doc_close_obj_msg)
  expect_error(pdf_text_font_size(in_annot_form[[1L]]), doc_close_obj_msg)
})

test_that("pdf_form_fields() pages close with their document", {
  doc <- pdf_doc_open(fixture_path("annotated"))
  fields <- pdf_form_fields(doc)
  pages <- attr(fields, "pages_used")
  expect_length(pages, 1L)
  expect_identical(
    pdfium:::cpp_doc_handle_counts(doc$ptr),
    c(annot = 2L, page = 1L, font = 0L, xobject = 0L)
  )
  pdf_doc_close(doc)
  expect_false(is_open(pages[[1L]]))
  expect_false(pdfium:::cpp_handle_is_valid(pages[[1L]]$ptr))
  expect_error(pdf_render_page(pages[[1L]]), doc_close_page_msg)
  expect_error(pdf_page_size(pages[[1L]]), doc_close_page_msg)
  expect_error(
    pdf_annot_subtype(fields[[1L]]),
    "Annotation handle has been closed"
  )
})

test_that("a pdf_form_fields() page keeps its document open", {
  # The document is opened inside pdf_form_fields() and never closed.
  fields <- pdf_form_fields(fixture_path("annotated"))
  page_ptr <- attr(fields, "pages_used")[[1L]]$ptr
  rm(fields)
  invisible(gc())
  # Only the page's externalptr is left. It pins its document, so the
  # document's finalizer has not closed the page.
  expect_identical(
    pdfium:::cpp_page_size(page_ptr),
    c(width = 300, height = 300)
  )
  pdfium:::cpp_close_page(page_ptr)
  expect_false(pdfium:::cpp_handle_is_valid(page_ptr))
})

test_that("pages and page-objects collected after pdf_doc_close() are safe", {
  # Each order in which a page, its page-objects and its document can
  # be collected once the document is closed or dropped.
  open_bundle <- function() {
    doc <- pdf_doc_open(fixture_path("unicode"))
    page <- pdf_page_load(doc, 1L)
    list(doc = doc, page = page, objs = pdf_page_objects(page))
  }
  b <- open_bundle()
  pdf_doc_close(b$doc)
  b$page <- NULL
  expect_no_error(gc())
  b$objs <- NULL
  expect_no_error(gc())
  b <- open_bundle()
  pdf_doc_close(b$doc)
  b$objs <- NULL
  expect_no_error(gc())
  b$page <- NULL
  expect_no_error(gc())
  b <- open_bundle()
  pdf_doc_close(b$doc)
  b$page <- NULL
  b$objs <- NULL
  expect_no_error(gc())
  # Never closed: the document and its page are collected together,
  # and their finalizers run in either order.
  b <- open_bundle()
  rm(b)
  expect_no_error(gc())
  # A page keeps its document open after the document is dropped.
  b <- open_bundle()
  b$doc <- NULL
  b$objs <- NULL
  expect_no_error(gc())
  expect_true(is_open(b$page))
  expect_identical(length(pdf_page_objects(b$page)), 6L)
  rm(b)
  expect_no_error(gc())
})

test_that("pdf_doc_close() leaves other documents' pages open", {
  doc_a <- pdf_doc_open(fixture_path("unicode"))
  doc_b <- pdf_doc_open(fixture_path("unicode"))
  on.exit(pdf_doc_close(doc_b), add = TRUE)
  # Collected page handles leave the registry, so doc_b's pages below
  # may reuse their memory without closing doc_a reaching them.
  for (i in seq_len(20L)) pdfium:::cpp_load_page(doc_a$ptr, 0L)
  invisible(gc())
  expect_identical(pdfium:::cpp_doc_handle_counts(doc_a$ptr), no_handles)
  page_a <- pdf_page_load(doc_a, 1L)
  pages_b <- lapply(seq_len(5L), function(i) pdf_page_load(doc_b, 1L))
  pdf_doc_close(doc_a)
  expect_false(is_open(page_a))
  expect_identical(vapply(pages_b, is_open, logical(1L)), rep(TRUE, 5L))
  expect_identical(
    pdfium:::cpp_doc_handle_counts(doc_b$ptr),
    c(annot = 0L, page = 5L, font = 0L, xobject = 0L)
  )
  expect_identical(nrow(pdf_text_runs(pages_b[[1L]])), 5L)
  expect_identical(dim(pdf_render_page(pages_b[[5L]])), c(216L, 288L))
})

test_that("a page closed or collected first leaves the document's registry", {
  doc <- pdf_doc_open(fixture_path("minimal"))
  kept <- pdf_page_load(doc, 1L)
  closed <- pdf_page_load(doc, 1L)
  local(pdfium:::cpp_load_page(doc$ptr, 0L))
  expect_identical(pdfium:::cpp_doc_handle_counts(doc$ptr)[["page"]], 3L)
  pdf_page_close(closed)
  expect_identical(pdfium:::cpp_doc_handle_counts(doc$ptr)[["page"]], 2L)
  invisible(gc())
  expect_identical(pdfium:::cpp_doc_handle_counts(doc$ptr)[["page"]], 1L)
  pdf_doc_close(doc)
  expect_false(is_open(kept))
  expect_false(pdfium:::cpp_handle_is_valid(closed$ptr))
})

test_that("cpp_doc_handle_counts() refuses a non-externalptr", {
  expect_error(
    pdfium:::cpp_doc_handle_counts("doc"),
    "^Expected an external pointer for the document\\.$"
  )
})
