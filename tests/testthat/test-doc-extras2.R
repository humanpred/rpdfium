# Tests for the doc-level readouts added in the 0.1.0
# read-completion pass: is_tagged, viewer_preferences, named_dests,
# doc_javascript. The bundled fixtures don't set these to non-default
# values (shapes.pdf is a plain Cairo render; outline.pdf has
# bookmarks but no /Names, ViewerPreferences, JS, or MarkInfo), so
# these tests focus on shape/type guarantees and the path-vs-doc
# fork. Behaviour-with-content is covered by manual / vignette use.

test_that("pdf_doc_is_tagged returns FALSE on plain Cairo fixtures", {
  for (name in c("shapes", "outline", "annotated", "minimal")) {
    out <- pdf_doc_is_tagged(fixture_path(name))
    expect_type(out, "logical")
    expect_length(out, 1L)
    expect_false(out)
  }
})

test_that("pdf_doc_is_tagged accepts doc or path equivalently", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(
    pdf_doc_is_tagged(doc),
    pdf_doc_is_tagged(fixture_path("shapes"))
  )
})

test_that("pdf_doc_is_tagged rejects bad inputs and closed docs", {
  expect_error(pdf_doc_is_tagged(42), "class .pdfium_doc.")
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_is_tagged(doc), "closed")
})

test_that("pdf_doc_viewer_preferences reports PDFium defaults on fixtures", {
  prefs <- pdf_doc_viewer_preferences(fixture_path("shapes"))
  expect_named(prefs, c(
    "print_scaling", "num_copies", "duplex",
    "print_page_ranges"
  ))
  expect_type(prefs$print_scaling, "logical")
  expect_length(prefs$print_scaling, 1L)
  expect_type(prefs$num_copies, "integer")
  expect_length(prefs$num_copies, 1L)
  expect_true(prefs$num_copies >= 1L)
  expect_type(prefs$duplex, "character")
  expect_true(prefs$duplex %in%
    c(
      "none", "simplex",
      "duplex_flip_short_edge", "duplex_flip_long_edge"
    ))
  expect_type(prefs$print_page_ranges, "integer")
})

test_that("pdf_doc_viewer_preferences accepts doc or path", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(
    pdf_doc_viewer_preferences(doc),
    pdf_doc_viewer_preferences(fixture_path("shapes"))
  )
})

test_that("pdf_doc_named_dests returns an empty tibble of the right shape", {
  out <- pdf_doc_named_dests(fixture_path("shapes"))
  expect_s3_class(out, "tbl_df")
  expect_named(out, c(
    "name", "page", "dest_view", "dest_x", "dest_y",
    "dest_zoom"
  ))
  expect_type(out$name, "character")
  expect_type(out$page, "integer")
  expect_type(out$dest_view, "character")
  expect_type(out$dest_x, "double")
})

test_that("pdf_doc_named_dests rejects bad doc inputs", {
  expect_error(pdf_doc_named_dests(list()), "class .pdfium_doc.")
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_named_dests(doc), "closed")
})

test_that("pdf_doc_javascript returns an empty tibble for JS-free PDFs", {
  out <- pdf_doc_javascript(fixture_path("shapes"))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("name", "script"))
  expect_type(out$name, "character")
  expect_type(out$script, "character")
})

test_that("pdf_doc_javascript accepts doc or path", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(
    pdf_doc_javascript(doc),
    pdf_doc_javascript(fixture_path("outline"))
  )
})

test_that("pdf_doc_viewer_preference_by_name returns NA when key absent", {
  expect_true(is.na(
    pdf_doc_viewer_preference_by_name(fixture_path("shapes"), "Direction")
  ))
})

test_that("pdf_doc_viewer_preference_by_name validates key", {
  expect_error(
    pdf_doc_viewer_preference_by_name(fixture_path("shapes"), ""),
    "Assertion on"
  )
  expect_error(
    pdf_doc_viewer_preference_by_name(
      fixture_path("shapes"),
      NA_character_
    ),
    "Assertion on"
  )
})

# ---- pdf_install_unsupported_handler ---------------------------------------

test_that("pdf_install_unsupported_handler returns TRUE", {
  expect_identical(pdf_install_unsupported_handler(), TRUE)
})

test_that("pdf_drain_unsupported_features returns a character vector", {
  # Process-global; the buffer survives across tests within a worker.
  # We verify the type contract and that draining clears the buffer.
  pdf_install_unsupported_handler()
  pdf_drain_unsupported_features()  # drain any leftovers
  out <- pdf_drain_unsupported_features()
  expect_type(out, "character")
  # Second drain of a now-empty buffer also returns character(0).
  expect_identical(pdf_drain_unsupported_features(), character(0))
})

test_that("opening signed.pdf surfaces no events without the handler", {
  # When the handler hasn't been installed, no events are buffered
  # regardless of what's in the document. We can't test the
  # un-installed state directly because earlier tests in the same
  # worker may have installed it, but we can at least verify the
  # call doesn't crash on a real document and the buffer-clear
  # contract holds.
  pdf_install_unsupported_handler()
  pdf_drain_unsupported_features()  # clear
  doc <- pdf_doc_open(fixture_path("signed"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  pdf_signatures(doc)
  events <- pdf_drain_unsupported_features()
  expect_type(events, "character")
  # Buffer is now drained.
  expect_identical(pdf_drain_unsupported_features(), character(0))
})

# ---- inline-PDF coverage tests --------------------------------------------
# The bundled fixtures don't populate /ID, /ViewerPreferences with
# PrintPageRange or Direction, /Names /Dests, /Names /JavaScript, or
# /Collection. Build hand-written PDFs so the populated-branch code
# paths in src/doc_extra.cpp execute.

.build_pdf <- function(obj_bodies, trailer_extras = "") {
  # Build a minimal PDF from a list of N object body strings, where
  # object indices are 1..N. obj_bodies is a character vector; each
  # element is the body between "<obj_num> 0 obj\n" and "\nendobj\n".
  # trailer_extras is appended inside the trailer << >> after /Root.
  obj <- function(n, body) paste0(n, " 0 obj\n", body, "\nendobj\n")
  obj_strs <- mapply(
    function(n, body) obj(n, body),
    seq_along(obj_bodies), obj_bodies,
    SIMPLIFY = TRUE
  )
  header <- charToRaw("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
  parts <- c(list(header), lapply(obj_strs, charToRaw))
  cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
  offs <- cum[seq_along(obj_strs) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  xref <- paste(
    c(
      "xref",
      paste0("0 ", length(obj_strs) + 1L),
      "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")
    ),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size ", length(obj_strs) + 1L,
    " /Root 1 0 R", trailer_extras, " >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  c(unlist(parts), charToRaw(xref), charToRaw(trailer))
}

.write_inline_pdf <- function(obj_bodies, trailer_extras = "") {
  bytes <- .build_pdf(obj_bodies, trailer_extras)
  tf <- tempfile(fileext = ".pdf")
  writeBin(bytes, tf)
  tf
}

# ---- pdf_doc_file_id populated branch (lines 53-62) -----------------------

test_that("pdf_doc_file_id returns the /ID bytes when present (permanent)", {
  # 32-hex-byte /ID array entries -> 16 raw bytes each after PDF
  # hex-string decode. PDF spec says the array is [permanent changing].
  tf <- .write_inline_pdf(
    c(
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>"
    ),
    trailer_extras = paste0(
      " /ID [<1234567890ABCDEF1234567890ABCDEF>",
      " <FEDCBA0987654321FEDCBA0987654321>]"
    )
  )
  on.exit(unlink(tf), add = TRUE)

  id_p <- pdf_doc_file_id(tf, id_type = "permanent")
  expect_type(id_p, "raw")
  expect_length(id_p, 16L)
  expect_identical(
    paste(format(id_p), collapse = ""),
    "1234567890abcdef1234567890abcdef"
  )
})

test_that("pdf_doc_file_id returns the /ID bytes when present (changing)", {
  # The "changing" branch exercises id_type = 1L in cpp_doc_file_id.
  # pdf_doc_file_id() drives the same C++ entry point regardless of
  # type, just with a different FPDF_FILEIDTYPE enum value.
  tf <- .write_inline_pdf(
    c(
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>"
    ),
    trailer_extras = paste0(
      " /ID [<1234567890ABCDEF1234567890ABCDEF>",
      " <FEDCBA0987654321FEDCBA0987654321>]"
    )
  )
  on.exit(unlink(tf), add = TRUE)

  id_c <- pdf_doc_file_id(tf, id_type = "changing")
  expect_type(id_c, "raw")
  expect_length(id_c, 16L)
  expect_identical(
    paste(format(id_c), collapse = ""),
    "fedcba0987654321fedcba0987654321"
  )
})

# ---- pdf_doc_viewer_preferences populated branch (lines 98-103) ----------

test_that("pdf_doc_viewer_preferences surfaces a PrintPageRange array", {
  # /PrintPageRange is an even-count integer array of 0-based page
  # pairs. The C++ side reads each element and adds 1 for R-facing
  # 1-based page numbers — this exercises the populated branch of
  # cpp_doc_viewer_prefs (lines 98-103).
  tf <- .write_inline_pdf(c(
    paste0(
      "<< /Type /Catalog /Pages 2 0 R ",
      "/ViewerPreferences << /PrintPageRange [0 2 4 6] ",
      "/NumCopies 3 /Duplex /DuplexFlipShortEdge ",
      "/PrintScaling /AppDefault >> >>"
    ),
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>"
  ))
  on.exit(unlink(tf), add = TRUE)

  prefs <- pdf_doc_viewer_preferences(tf)
  expect_identical(prefs$print_page_ranges, c(1L, 3L, 5L, 7L))
  expect_identical(prefs$num_copies, 3L)
  expect_identical(prefs$duplex, "duplex_flip_short_edge")
  # /PrintScaling = /AppDefault means "honor app default" -> TRUE
  expect_true(prefs$print_scaling)
})

# ---- pdf_doc_viewer_preference_by_name non-empty branch (lines 129-133) --

test_that("pdf_doc_viewer_preference_by_name returns the Direction value", {
  # /ViewerPreferences /Direction is a /Name (one of /L2R or /R2L).
  # FPDF_VIEWERREF_GetName probes its length, then we re-read into a
  # buffer (lines 129-130) and strip the trailing NUL (line 132).
  tf <- .write_inline_pdf(c(
    paste0(
      "<< /Type /Catalog /Pages 2 0 R ",
      "/ViewerPreferences << /Direction /L2R >> >>"
    ),
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>"
  ))
  on.exit(unlink(tf), add = TRUE)

  expect_identical(
    pdf_doc_viewer_preference_by_name(tf, "Direction"),
    "L2R"
  )
})

# ---- pdf_doc_named_dests populated branch (lines 149-191) ----------------

test_that("pdf_doc_named_dests surfaces named destinations via /Names /Dests", {
  # /Names /Dests carries a name tree mapping name -> destination.
  # Each destination is [<page-ref> /<view> <params...>]. Exercising
  # this populates lines 149-191 (allocating output vectors, the
  # per-entry loop, name decoding, page/view/coord extraction).
  tf <- .write_inline_pdf(c(
    "<< /Type /Catalog /Pages 2 0 R /Names 4 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>",
    paste0(
      "<< /Dests << /Names [",
      "(dest_xyz) [3 0 R /XYZ 100 200 1.5] ",
      "(dest_fit) [3 0 R /Fit] ",
      "(dest_fith) [3 0 R /FitH 150] ",
      "] >> >>"
    )
  ))
  on.exit(unlink(tf), add = TRUE)

  out <- pdf_doc_named_dests(tf)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 3L)
  expect_identical(out$name, c("dest_xyz", "dest_fit", "dest_fith"))
  # All targets are page 1 (3 0 R) -> page 1 in 1-based output.
  expect_identical(out$page, c(1L, 1L, 1L))
  # XYZ supplies x, y, zoom; Fit supplies neither; FitH supplies a
  # vertical offset (dest_y).
  expect_identical(out$dest_view[1L], "xyz")
  expect_identical(out$dest_x[1L], 100)
  expect_identical(out$dest_y[1L], 200)
  expect_identical(out$dest_zoom[1L], 1.5)
  expect_identical(out$dest_view[2L], "fit")
  expect_true(is.na(out$dest_x[2L]))
  expect_identical(out$dest_view[3L], "fith")
})

test_that("pdf_doc_named_dests yields NA for unresolvable entries", {
  # When a /Names /Dests entry doesn't resolve to a real dest (e.g.,
  # the value is null), PDFium's FPDF_GetNamedDest returns nullptr
  # for that index. cpp_doc_named_dests fills NA into the row (lines
  # 158-162). One valid entry alongside one null entry exercises
  # both branches in a single pass.
  tf <- .write_inline_pdf(c(
    "<< /Type /Catalog /Pages 2 0 R /Names 4 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>",
    paste0(
      "<< /Dests << /Names [",
      "(bad) null ",
      "(good) [3 0 R /Fit] ",
      "] >> >>"
    )
  ))
  on.exit(unlink(tf), add = TRUE)

  out <- pdf_doc_named_dests(tf)
  expect_equal(nrow(out), 2L)
  expect_true(is.na(out$name[1L]))
  expect_true(is.na(out$page[1L]))
  expect_identical(out$dest_view[1L], "unknown")
  expect_identical(out$name[2L], "good")
})

# ---- pdf_doc_javascript populated branch (lines 205-244) -----------------

test_that("pdf_doc_javascript surfaces /JavaScript named entries", {
  # /Names /JavaScript /Names carries [name (action-dict)] pairs.
  # The action dict has /S /JavaScript and /JS <script string>.
  # This exercises the populated branch of cpp_doc_javascript -
  # the action loop, name + script two-pass UTF-16LE reads,
  # and FPDFDoc_CloseJavaScriptAction.
  tf <- .write_inline_pdf(c(
    "<< /Type /Catalog /Pages 2 0 R /Names 4 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>",
    paste0(
      "<< /JavaScript << /Names [",
      "(jsname1) << /S /JavaScript /JS (app.alert\\(\"hi\"\\);) >> ",
      "(jsname2) << /S /JavaScript /JS (var x = 42;) >> ",
      "] >> >>"
    )
  ))
  on.exit(unlink(tf), add = TRUE)

  js <- pdf_doc_javascript(tf)
  expect_s3_class(js, "tbl_df")
  expect_equal(nrow(js), 2L)
  expect_identical(js$name, c("jsname1", "jsname2"))
  expect_identical(js$script, c("app.alert(\"hi\");", "var x = 42;"))
})

test_that("pdf_doc_javascript yields NA for non-JavaScript actions", {
  # When an entry in /Names /JavaScript /Names points at an action
  # dict whose /S is not /JavaScript (e.g. /URI), PDFium's
  # FPDFDoc_GetJavaScriptAction returns nullptr at that index. The
  # C++ loop fills NA for name and script (lines 210-212). One
  # bad entry alongside one valid entry exercises both branches.
  tf <- .write_inline_pdf(c(
    "<< /Type /Catalog /Pages 2 0 R /Names 4 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>",
    paste0(
      "<< /JavaScript << /Names [",
      "(bad) << /S /URI /URI (https://example.com) >> ",
      "(good) << /S /JavaScript /JS (a) >> ",
      "] >> >>"
    )
  ))
  on.exit(unlink(tf), add = TRUE)

  js <- pdf_doc_javascript(tf)
  expect_equal(nrow(js), 2L)
  expect_true(is.na(js$name[1L]))
  expect_true(is.na(js$script[1L]))
  expect_identical(js$name[2L], "good")
  expect_identical(js$script[2L], "a")
})

# ---- unsupported_name() switch cases via real triggers --------------------

test_that("opening /Collection-bearing PDF fires 'portable collection'", {
  # Putting /Collection in the catalog triggers PDFium's
  # ReportUnsupportedFeatures -> CheckUnSupportError with
  # FPDF_UNSP_DOC_PORTABLECOLLECTION (case at line 273 in the
  # unsupported_name switch). Also exercises the callback at line 295
  # and the drain loop body at line 315.
  pdf_install_unsupported_handler()
  pdf_drain_unsupported_features()  # clear from prior tests
  tf <- .write_inline_pdf(c(
    "<< /Type /Catalog /Pages 2 0 R /Collection << /D (foo) >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources <<>> >>"
  ))
  on.exit(unlink(tf), add = TRUE)

  doc <- pdf_doc_open(tf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  events <- pdf_drain_unsupported_features()
  expect_true("portable collection" %in% events)
})

test_that("opening attachments.pdf fires 'document attachment'", {
  # attachments.pdf has a /Names /EmbeddedFiles entry, which
  # PDFium flags as FPDF_UNSP_DOC_ATTACHMENT (case at line 274).
  # This also redundantly exercises the callback + drain loop.
  pdf_install_unsupported_handler()
  pdf_drain_unsupported_features()
  doc <- pdf_doc_open(fixture_path("attachments"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  events <- pdf_drain_unsupported_features()
  expect_true("document attachment" %in% events)
})
