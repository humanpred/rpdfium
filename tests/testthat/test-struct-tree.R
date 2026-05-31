# Tests for pdf_structure_tree(). tagged.pdf is a hand-built single-
# page PDF whose catalog declares a /StructTreeRoot containing a
# Document element with three children (H1 / P / Figure). Only the
# P element has marked content on the page (MCID 0), so PDFium's
# per-page view of the tree (FPDF_StructTree_GetForPage) surfaces
# just the Document + P pair — H1 and Figure are filtered out
# because they have no content on this page.

test_that("pdf_structure_tree returns 0 rows for an untagged PDF", {
  for (name in c("shapes", "minimal", "annotated")) {
    out <- pdf_structure_tree(pdf_doc_open(fixture_path(name)), 1L)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
    expect_named(out, c(
      "element_index", "parent_index", "level",
      "type", "parent_type", "obj_type", "title", "lang",
      "alt_text", "actual_text", "expansion", "id",
      "mcid", "mcid_count", "attributes", "child_mcids"
    ))
  }
})

test_that("pdf_structure_tree walks the tagged-PDF tree", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, page_num = 1L)
  expect_s3_class(res, "tbl_df")
  # PDFium's per-page view only returns elements with content on
  # the page (Document + P). H1 and Figure are filtered out.
  expect_equal(nrow(res), 2L)
  expect_identical(res$element_index, 1L:2L)
  expect_identical(res$type, c("Document", "P"))
  expect_identical(res$parent_index, c(0L, 1L))
  expect_identical(res$level, c(1L, 2L))
  # P has marked content (/MCR with MCID 0); Document does not.
  expect_true(is.na(res$mcid[[1L]]))
  expect_equal(res$mcid[[2L]], 0L)
  expect_equal(res$mcid_count[[1L]], 0L)
  expect_equal(res$mcid_count[[2L]], 1L)
  # parent_type: Document is at the tree root (empty parent type),
  # P's parent is the Document element above it.
  expect_identical(res$parent_type, c("", "Document"))
  # expansion (/E) column (chromium/7857+): the tagged fixture declares
  # no /E expansion text, so both surfaced rows are empty strings.
  expect_identical(res$expansion, c("", ""))
  # child_mcids: the per-page walk surfaces just Document + P, but
  # the underlying CountChildren still reports the full tree —
  # Document has H1/P/Figure (all nested struct-elements, so all
  # NA), and P has one MCR child (MCID 0).
  expect_type(res$child_mcids, "list")
  expect_length(res$child_mcids, 2L)
  expect_true(all(is.na(res$child_mcids[[1L]])))
  expect_equal(length(res$child_mcids[[1L]]), 3L)
  expect_identical(res$child_mcids[[2L]], 0L)
})

test_that("pdf_structure_tree surfaces typed /A attribute values", {
  # The tagged.pdf P element carries an /A Layout attribute with
  # values of every type the read_attr_value() branches handle:
  # Boolean, Number, String, Name, Array of Number, Array of Name.
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, 1L)
  attrs <- res$attributes[[2L]]
  expect_setequal(names(attrs),
                    c("O", "Placement", "SpaceBefore", "BBox",
                      "BorderStyle", "Hidden"))
  # Name branch -> character.
  expect_identical(attrs$O, "Layout")
  expect_identical(attrs$Placement, "Block")
  # Number branch -> numeric.
  expect_equal(attrs$SpaceBefore, 12.5)
  # Array-of-Number branch -> list of numeric.
  expect_type(attrs$BBox, "list")
  expect_length(attrs$BBox, 4L)
  expect_equal(unlist(attrs$BBox), c(10, 20, 110, 120))
  # Array-of-Name branch -> list of character.
  expect_type(attrs$BorderStyle, "list")
  expect_length(attrs$BorderStyle, 4L)
  expect_identical(unlist(attrs$BorderStyle),
                    c("Solid", "Solid", "Solid", "Solid"))
  # Boolean branch -> logical.
  expect_identical(attrs$Hidden, FALSE)
})

test_that("pdf_structure_tree honours string_attrs", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # The tagged.pdf P element's /A entry carries /Placement /Block
  # and /O /Layout — both are name-typed attributes that
  # FPDF_StructElement_GetStringAttribute should return verbatim.
  # /Headers is absent on every element, so it returns "" — that
  # exercises the empty-buffer early-return path.
  res <- pdf_structure_tree(doc, page_num = 1L,
                              string_attrs = c("Placement", "O", "Headers"))
  expect_true(all(c("Placement", "O", "Headers") %in% colnames(res)))
  # Document (row 1) has no /A so all three are empty.
  expect_identical(res$Placement[[1L]], "")
  expect_identical(res$O[[1L]], "")
  expect_identical(res$Headers[[1L]], "")
  # P (row 2) has /A with Placement=Block and O=Layout — non-empty
  # branch of read_string_attribute, verifying UTF-16LE decoding.
  expect_identical(res$Placement[[2L]], "Block")
  expect_identical(res$O[[2L]], "Layout")
  expect_identical(res$Headers[[2L]], "")
})

test_that("pdf_structure_tree's empty-tibble path includes string_attrs", {
  out <- pdf_structure_tree(pdf_doc_open(fixture_path("minimal")),
                              page_num = 1L,
                              string_attrs = c("Scope"))
  expect_equal(nrow(out), 0L)
  expect_true("Scope" %in% colnames(out))
  expect_type(out$Scope, "character")
})

test_that("pdf_structure_tree validates string_attrs", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  # Non-character input is rejected by checkmate.
  expect_error(pdf_structure_tree(doc, string_attrs = 1L),
                 "Assertion on")
  # Empty-string elements are rejected (min.chars = 1L).
  expect_error(pdf_structure_tree(doc, string_attrs = c("Lang", "")),
                 "Assertion on")
  # NA elements are rejected.
  expect_error(pdf_structure_tree(doc, string_attrs = NA_character_),
                 "Assertion on")
})

test_that("pdf_structure_tree accepts a doc + page_num or a page", {
  doc <- pdf_doc_open(fixture_path("tagged"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  by_doc <- pdf_structure_tree(doc, page_num = 1L)
  page <- pdf_page_load(doc, 1L)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  by_page <- pdf_structure_tree(page)
  expect_identical(by_doc, by_page)
})

test_that("pdf_structure_tree rejects bad inputs and closed pages", {
  expect_error(
    pdf_structure_tree("nope"),
    "class .pdfium_page./.pdfium_doc."
  )
  doc <- pdf_doc_open(fixture_path("tagged"))
  page <- pdf_page_load(doc, 1L)
  pdf_page_close(page)
  expect_error(pdf_structure_tree(page), "closed")
  pdf_doc_close(doc)
})

test_that("pdf_structure_tree surfaces a direct /K integer marked-content reference", {
  # The bundled tagged.pdf binds its P element to MCID 0 via an
  # MCR child (/K << /Type /MCR ... >>). Tagged PDFs may also bind
  # an element to a marked-content range *directly* by setting /K
  # to an integer — that's the FPDF_StructElement_GetMarkedContentID
  # branch of resolve_element_mcid() (src/struct_tree.cpp lines
  # 192-195). This test constructs a minimal tagged PDF that uses
  # the direct-integer form so the GetMarkedContentID path is
  # exercised. We build the PDF in-test rather than as a bundled
  # fixture because the only consumer is this single coverage check.
  obj <- function(n, body) paste0(n, " 0 obj\n", body, "\nendobj\n")
  page_content <- paste(
    "q",
    "/Span <</MCID 0>> BDC",
    "0.8 0.2 0.2 RG",
    "1 w",
    "10 10 80 80 re",
    "S",
    "EMC",
    "Q",
    sep = "\n"
  )
  page_content_bytes <- charToRaw(paste0(page_content, "\n"))
  obj1 <- obj(1, paste0(
    "<< /Type /Catalog /Pages 2 0 R /StructTreeRoot 4 0 R ",
    "/MarkInfo << /Marked true >> >>"
  ))
  obj2 <- obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
  obj3 <- obj(3, paste0(
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] ",
    "/Resources <<>> /StructParents 0 /Contents 7 0 R >>"
  ))
  obj4 <- obj(4, paste0(
    "<< /Type /StructTreeRoot /K 5 0 R /ParentTree 8 0 R ",
    "/ParentTreeNextKey 1 >>"
  ))
  obj5 <- obj(5, paste0(
    "<< /Type /StructElem /S /Document /P 4 0 R /K [6 0 R] >>"
  ))
  # Span element uses /K 0 (direct integer) — this is the path
  # under test. PDFium FPDF_StructElement_GetMarkedContentID then
  # returns 0 rather than -1.
  obj6 <- obj(6, paste0(
    "<< /Type /StructElem /S /Span /P 5 0 R /Pg 3 0 R /K 0 >>"
  ))
  obj7_head <- paste0("7 0 obj\n<< /Length ",
                      length(page_content_bytes), " >>\nstream\n")
  obj7_bytes <- c(charToRaw(obj7_head), page_content_bytes,
                  charToRaw("\nendstream\nendobj\n"))
  obj8 <- obj(8, "<< /Nums [0 [6 0 R]] >>")
  header <- charToRaw("%PDF-1.5\n%\xe2\xe3\xcf\xd3\n")
  parts <- list(
    header, charToRaw(obj1), charToRaw(obj2), charToRaw(obj3),
    charToRaw(obj4), charToRaw(obj5), charToRaw(obj6),
    obj7_bytes, charToRaw(obj8)
  )
  cum <- c(0L, cumsum(vapply(parts, length, integer(1))))
  offs <- cum[seq_len(8L) + 1L]
  xref_offset <- cum[[length(cum)]]
  fmt10 <- function(n) sprintf("%010d", n)
  xref <- paste(
    c("xref",
      "0 9",
      "0000000000 65535 f ",
      paste0(fmt10(offs), " 00000 n ")),
    collapse = "\n"
  )
  trailer <- paste0(
    "\ntrailer\n<< /Size 9 /Root 1 0 R >>\nstartxref\n",
    xref_offset, "\n%%EOF\n"
  )
  full <- c(unlist(parts), charToRaw(xref), charToRaw(trailer))
  tf <- withr::local_tempfile(fileext = ".pdf")
  writeBin(full, tf)

  doc <- pdf_doc_open(tf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  res <- pdf_structure_tree(doc, page_num = 1L)
  # The per-page walk surfaces Document + Span (Span has MCID 0
  # via direct /K). Document is still mcid=NA (container element).
  expect_equal(nrow(res), 2L)
  expect_identical(res$type, c("Document", "Span"))
  # Span uses direct /K integer: mcid == 0 with mcid_count == 1
  # (the resolve_element_mcid direct-integer branch).
  expect_true(is.na(res$mcid[[1L]]))
  expect_equal(res$mcid[[2L]], 0L)
  expect_equal(res$mcid_count[[2L]], 1L)
})
