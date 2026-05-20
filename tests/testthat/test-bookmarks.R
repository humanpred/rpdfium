# Tests for pdf_doc_bookmarks() (now returns a pdfium_bookmark_list)
# and the handle-based per-attribute getters, plus pdf_page_label(),
# pdf_page_labels(), and pdf_doc_permissions(). outline.pdf is a
# hand-built two-page fixture with:
#
#   Chapter 1     (level 1, page 1)
#     Section 1.1 (level 2, page 1)
#     Section 1.2 (level 2, page 2)
#
# and PageLabels mapping page 1 -> "i", page 2 -> "1".
# shapes.pdf is a Cairo PDF with no outline / no labels and is
# unencrypted; we use it for the empty-tree and all-permissions
# branches.

# pdf_doc_bookmarks ----------------------------------------------------

test_that("pdf_doc_bookmarks returns a pdfium_bookmark_list", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bm <- pdf_doc_bookmarks(doc)
  expect_s3_class(bm, "pdfium_bookmark_list")
  expect_length(bm, 3L)
  expect_s3_class(bm[[1L]], "pdfium_bookmark")
})

test_that("pdf_doc_bookmarks returns 0 handles for a doc without an outline", {
  res <- pdf_doc_bookmarks(fixture_path("shapes"))
  expect_s3_class(res, "pdfium_bookmark_list")
  expect_length(res, 0L)
  tbl <- tibble::as_tibble(res)
  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 0L)
  expect_named(tbl, c(
    "bookmark_index", "parent_index", "level",
    "title", "page_num", "action_type", "uri",
    "filepath", "dest_view", "dest_x", "dest_y",
    "dest_zoom", "handle", "source"
  ))
})

test_that("tibble view returns the documented bookmark columns + handle/source", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  bm <- tibble::as_tibble(pdf_doc_bookmarks(doc))
  expect_s3_class(bm, "tbl_df")
  expect_named(bm, c(
    "bookmark_index", "parent_index", "level",
    "title", "page_num", "action_type", "uri",
    "filepath", "dest_view", "dest_x", "dest_y",
    "dest_zoom", "handle", "source"
  ))
  expect_type(bm$bookmark_index, "integer")
  expect_type(bm$parent_index, "integer")
  expect_type(bm$level, "integer")
  expect_type(bm$title, "character")
  expect_type(bm$page_num, "integer")
  expect_type(bm$action_type, "character")
  expect_type(bm$uri, "character")
  expect_type(bm$filepath, "character")
  expect_type(bm$handle, "list")
  expect_type(bm$source, "list")
})

test_that("pdf_doc_bookmarks reads the outline tree depth-first", {
  bm <- tibble::as_tibble(pdf_doc_bookmarks(fixture_path("outline")))
  expect_equal(nrow(bm), 3L)
  expect_identical(bm$bookmark_index, 1L:3L)
  expect_identical(
    bm$title,
    c("Chapter 1", "Section 1.1", "Section 1.2")
  )
  expect_identical(bm$level, c(1L, 2L, 2L))
  expect_identical(bm$parent_index, c(0L, 1L, 1L))
  expect_identical(bm$page_num, c(1L, 1L, 2L))
  # All three bookmarks resolve to a within-doc /Dest, so
  # action_type is "goto" everywhere and URI / filepath are NA.
  expect_identical(bm$action_type, rep("goto", 3L))
  expect_true(all(is.na(bm$uri)))
  expect_true(all(is.na(bm$filepath)))
})

test_that("pdf_doc_bookmarks accepts a path or an open doc", {
  by_path <- tibble::as_tibble(pdf_doc_bookmarks(fixture_path("outline")))
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- tibble::as_tibble(pdf_doc_bookmarks(doc))
  drop_handle <- function(t) {
    t[, !names(t) %in% c("handle", "source")]
  }
  expect_identical(drop_handle(by_path), drop_handle(by_doc))
  expect_true(is_open(doc))
})

test_that("pdf_doc_bookmarks rejects bad inputs and closed docs", {
  expect_error(pdf_doc_bookmarks(42), "class .pdfium_doc.")
  doc <- pdf_doc_open(fixture_path("outline"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_bookmarks(doc), "Document has been closed")
})

# Per-handle getters ------------------------------------------------

test_that("per-handle bookmark getters return the documented fields", {
  bm <- pdf_doc_bookmarks(fixture_path("outline"))
  b1 <- bm[[1L]]
  expect_identical(pdf_bookmark_title(b1), "Chapter 1")
  expect_identical(pdf_bookmark_page_num(b1), 1L)
  expect_identical(pdf_bookmark_action_type(b1), "goto")
  expect_true(is.na(pdf_bookmark_uri(b1)))
  expect_true(is.na(pdf_bookmark_filepath(b1)))
  expect_type(pdf_bookmark_dest_view(b1), "character")
  expect_type(pdf_bookmark_dest_x(b1), "double")
  expect_type(pdf_bookmark_dest_y(b1), "double")
  expect_type(pdf_bookmark_dest_zoom(b1), "double")
})

test_that("per-handle getters reject non-bookmark input", {
  expect_error(pdf_bookmark_title("nope"), "Assertion on")
  expect_error(pdf_bookmark_page_num(42), "Assertion on")
  expect_error(pdf_bookmark_action_type(NULL), "Assertion on")
  expect_error(pdf_bookmark_uri(0L), "Assertion on")
  expect_error(pdf_bookmark_filepath(0L), "Assertion on")
  expect_error(pdf_bookmark_dest_view(0L), "Assertion on")
  expect_error(pdf_bookmark_dest_x(0L), "Assertion on")
  expect_error(pdf_bookmark_dest_y(0L), "Assertion on")
  expect_error(pdf_bookmark_dest_zoom(0L), "Assertion on")
})

test_that("pdfium_bookmark print shows title + index + level", {
  bm <- pdf_doc_bookmarks(fixture_path("outline"))
  out <- capture.output(print(bm[[1L]]))
  expect_true(any(grepl("Chapter 1", out)))
  expect_true(any(grepl("idx 1", out)))
  expect_true(any(grepl("level 1", out)))
})

test_that("pdfium_bookmark_list print shows count", {
  bm <- pdf_doc_bookmarks(fixture_path("outline"))
  txt <- capture.output(print(bm))
  expect_true(any(grepl("3 bookmark\\(s\\)", txt)))
})

test_that("pdfium_bookmark_list print truncates beyond 5 entries", {
  bm <- pdf_doc_bookmarks(fixture_path("outline"))
  many <- structure(
    rep(unclass(bm), 3L),
    source = attr(bm, "source"),
    class = c("pdfium_bookmark_list", "list")
  )
  txt <- capture.output(print(many))
  expect_true(any(grepl("more", txt)))
})

test_that("as_pdfium_bookmark_list round-trips from tibble", {
  bm <- pdf_doc_bookmarks(fixture_path("outline"))
  tbl <- tibble::as_tibble(bm)
  back <- as_pdfium_bookmark_list(tbl)
  expect_s3_class(back, "pdfium_bookmark_list")
  expect_identical(back[[1L]]$ptr, bm[[1L]]$ptr)
  expect_identical(back[[1L]]$index, bm[[1L]]$index)
})

test_that("as_pdfium_bookmark_list is a no-op on existing handle lists", {
  bm <- pdf_doc_bookmarks(fixture_path("outline"))
  expect_identical(as_pdfium_bookmark_list(bm), bm)
})

test_that("as_pdfium_bookmark_list accepts a plain list of handles", {
  bm <- pdf_doc_bookmarks(fixture_path("outline"))
  plain <- unclass(bm)
  back <- as_pdfium_bookmark_list(plain)
  expect_s3_class(back, "pdfium_bookmark_list")
})

test_that("as_pdfium_bookmark_list errors on unrecognised input", {
  expect_error(as_pdfium_bookmark_list("nope"),
               "must be a .pdfium_bookmark_list.")
  expect_error(
    as_pdfium_bookmark_list(tibble::tibble(handle = list(),
                                            source = list())),
    "zero-row"
  )
})

test_that("bookmark handle invalidates when its parent doc closes", {
  doc <- pdf_doc_open(fixture_path("outline"))
  bm <- pdf_doc_bookmarks(doc)
  b1 <- bm[[1L]]
  expect_true(is_open(b1))
  pdf_doc_close(doc)
  expect_false(is_open(b1))
  expect_error(pdf_bookmark_title(b1), "has been closed")
})

# pdf_page_label / pdf_page_labels ---------------------------------

test_that("pdf_page_labels() reads the PageLabels number tree", {
  expect_identical(
    pdf_page_labels(fixture_path("outline")),
    c("i", "1")
  )
})

test_that("pdf_page_label() reads one page's label", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_identical(pdf_page_label(doc, 1L), "i")
  expect_identical(pdf_page_label(doc, 2L), "1")
})

test_that("pdf_page_labels() returns empty strings for PDFs without a labels table", {
  # shapes.pdf has no /PageLabels entry. PDFium returns the empty
  # string for every page rather than synthesising a label.
  labs <- pdf_page_labels(fixture_path("shapes"))
  expect_length(labs, 1L)
  expect_identical(labs, "")
})

test_that("pdf_page_label() validates page_num", {
  doc <- pdf_doc_open(fixture_path("outline"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  expect_error(
    pdf_page_label(doc, 0),
    "Assertion on"
  )
  expect_error(
    pdf_page_label(doc, -1),
    "Assertion on"
  )
  expect_error(
    pdf_page_label(doc, 1.5),
    "Assertion on"
  )
  expect_error(
    pdf_page_label(doc, NA_integer_),
    "Assertion on"
  )
  expect_error(
    pdf_page_label(doc, c(1, 2)),
    "Assertion on"
  )
})

# pdf_doc_permissions ---------------------------------------------

test_that("pdf_doc_permissions() reports all flags TRUE for an unencrypted PDF", {
  p <- pdf_doc_permissions(fixture_path("shapes"))
  expect_type(p, "logical")
  expect_named(p, c(
    "print", "modify", "copy", "annotate",
    "fill_forms", "extract_for_a11y", "assemble",
    "print_high_res"
  ))
  expect_true(all(p))
})

test_that("pdf_doc_permissions() accepts a path or an open doc", {
  by_path <- pdf_doc_permissions(fixture_path("shapes"))
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_doc_permissions(doc)
  expect_identical(by_path, by_doc)
})

test_that("pdf_doc_permissions() rejects closed docs", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  expect_error(pdf_doc_permissions(doc), "Document has been closed")
})

# pdf_doc_security / user_permissions / xref_valid / trailer_ends ---

test_that("pdf_doc_security returns NA for unencrypted PDFs", {
  expect_true(is.na(pdf_doc_security(fixture_path("shapes"))))
  expect_true(is.na(pdf_doc_security(fixture_path("outline"))))
})

test_that("pdf_doc_user_permissions matches pdf_doc_permissions when unencrypted", {
  expect_identical(
    pdf_doc_user_permissions(fixture_path("shapes")),
    pdf_doc_permissions(fixture_path("shapes"))
  )
})

test_that("pdf_doc_xref_valid is TRUE for PDFium-built fixtures", {
  expect_true(pdf_doc_xref_valid(fixture_path("shapes")))
  expect_true(pdf_doc_xref_valid(fixture_path("outline")))
})

test_that("pdf_doc_trailer_ends returns at least one offset per PDF", {
  ends <- pdf_doc_trailer_ends(fixture_path("shapes"))
  expect_type(ends, "integer")
  expect_gte(length(ends), 1L)
  expect_true(all(ends > 0L))
})

test_that("doc-health helpers reject closed docs", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  pdf_doc_close(doc)
  for (fn in list(
    pdf_doc_security, pdf_doc_user_permissions,
    pdf_doc_xref_valid, pdf_doc_trailer_ends
  )) {
    expect_error(fn(doc), "Document has been closed")
  }
})
