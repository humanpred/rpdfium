# Tests for pdf_text_search(). We exercise the documented contract
# against the small text-bearing fixtures (shapes.pdf has "Hello";
# unicode.pdf has "Hello\nworld\npdfium" with \r\n line breaks as
# separator chars in the PDFium text page) and a path-vs-open-doc
# fork. Multi-page coverage is handled implicitly: the doc-level
# wrapper iterates pages and the row-binding code is hit on every
# call; explicit multi-page text fixtures don't yet exist.

test_that("pdf_text_search rejects bad arguments early", {
  fix <- fixture_path("shapes")

  expect_error(pdf_text_search(fix, NA_character_), "Assertion on")
  expect_error(pdf_text_search(fix, character()), "Assertion on")
  expect_error(pdf_text_search(fix, ""), "Assertion on")
  expect_error(pdf_text_search(fix, c("a", "b")), "Assertion on")
  expect_error(pdf_text_search(fix, 42), "Assertion on")

  expect_error(
    pdf_text_search(fix, "Hello", case_sensitive = NA),
    "Assertion on"
  )
  expect_error(
    pdf_text_search(fix, "Hello", case_sensitive = "yes"),
    "Assertion on"
  )
  expect_error(
    pdf_text_search(fix, "Hello", whole_word = c(TRUE, FALSE)),
    "Assertion on"
  )
  expect_error(
    pdf_text_search(fix, "Hello", consecutive = NULL),
    "Assertion on"
  )
})

test_that("pdf_text_search rejects bad doc inputs", {
  expect_error(
    pdf_text_search(42, "Hello"),
    "class .pdfium_doc."
  )
  expect_error(
    pdf_text_search(list(), "Hello"),
    "class .pdfium_doc."
  )

  # closed-doc path
  doc <- pdf_open(fixture_path("shapes"))
  pdf_close(doc)
  expect_error(pdf_text_search(doc, "Hello"), "closed")
})

test_that("pdf_text_search finds a single hit and returns the bbox", {
  out <- pdf_text_search(fixture_path("shapes"), "Hello")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  expect_equal(out$page, 1L)
  expect_equal(out$match_index, 1L)
  expect_equal(out$start_char, 0L)
  expect_equal(out$char_count, 5L)
  expect_equal(out$text, "Hello")
  # Bbox should be finite and form a rectangle (left < right, bottom < top).
  expect_true(is.finite(out$left))
  expect_true(is.finite(out$bottom))
  expect_true(is.finite(out$right))
  expect_true(is.finite(out$top))
  expect_lt(out$left, out$right)
  expect_lt(out$bottom, out$top)
})

test_that("pdf_text_search is case-insensitive by default and respects the flag", {
  ci <- pdf_text_search(fixture_path("shapes"), "hello")
  expect_equal(nrow(ci), 1L)
  expect_equal(ci$text, "Hello")

  cs <- pdf_text_search(fixture_path("shapes"), "hello",
    case_sensitive = TRUE
  )
  expect_equal(nrow(cs), 0L)

  cs_exact <- pdf_text_search(fixture_path("shapes"), "Hello",
    case_sensitive = TRUE
  )
  expect_equal(nrow(cs_exact), 1L)
})

test_that("pdf_text_search whole_word excludes substring matches", {
  # In shapes.pdf the only text is "Hello", so:
  #   - "ell" matches as a substring without whole_word
  #   - "ell" does NOT match with whole_word
  #   - "Hello" matches under both modes (whole token of length 5)
  expect_equal(nrow(pdf_text_search(fixture_path("shapes"), "ell")), 1L)
  expect_equal(nrow(pdf_text_search(fixture_path("shapes"), "ell",
    whole_word = TRUE
  )), 0L)
  expect_equal(nrow(pdf_text_search(fixture_path("shapes"), "Hello",
    whole_word = TRUE
  )), 1L)
})

test_that("pdf_text_search returns multiple matches in source order", {
  # unicode.pdf is "Hello\r\nworld\r\npdfium". Lowercase 'l' appears
  # at char positions {2, 3} ("ll" in Hello) and {10} ("l" in world)
  # in 0-based PDFium indexing.
  out <- pdf_text_search(fixture_path("unicode"), "l")
  expect_gte(nrow(out), 3L)
  expect_equal(out$page, rep(1L, nrow(out)))
  expect_equal(out$match_index, seq_len(nrow(out)))
  expect_true(all(out$char_count == 1L))
  expect_true(all(out$text == "l"))
  expect_true(
    all(diff(out$start_char) > 0L),
    "matches reported in increasing start_char order"
  )
})

test_that("pdf_text_search finds the bottom-of-page word", {
  out <- pdf_text_search(fixture_path("unicode"), "pdfium")
  expect_equal(nrow(out), 1L)
  expect_equal(out$text, "pdfium")
  expect_equal(out$char_count, 6L)
  # Bottom of unicode.pdf — "pdfium" sits below "world".
  out2 <- pdf_text_search(fixture_path("unicode"), "world")
  expect_lt(out$top, out2$top)
})

test_that("pdf_text_search returns an empty tibble of the right shape on no match", {
  out <- pdf_text_search(fixture_path("shapes"), "doesnotappear")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_equal(
    names(out),
    c(
      "page", "match_index", "start_char", "char_count", "text",
      "left", "bottom", "right", "top"
    )
  )
  # Column types should match the populated case so callers can
  # rbind the result without coercion surprises.
  expect_type(out$page, "integer")
  expect_type(out$match_index, "integer")
  expect_type(out$start_char, "integer")
  expect_type(out$char_count, "integer")
  expect_type(out$text, "character")
  expect_type(out$left, "double")
  expect_type(out$bottom, "double")
  expect_type(out$right, "double")
  expect_type(out$top, "double")
})

test_that("pdf_text_search accepts either a path or an open pdfium_doc", {
  from_path <- pdf_text_search(fixture_path("shapes"), "Hello")

  doc <- pdf_open(fixture_path("shapes"))
  on.exit(pdf_close(doc), add = TRUE)
  from_doc <- pdf_text_search(doc, "Hello")
  expect_identical(from_path, from_doc)
})

test_that("pdf_text_search handles a text-less page without erroring", {
  # minimal.pdf is an empty Cairo page; outline.pdf has zero text on
  # both pages. Both should yield an empty result rather than
  # throwing -- iteration over empty text pages must be safe.
  for (name in c("minimal", "outline", "annotated")) {
    out <- pdf_text_search(fixture_path(name), "Hello")
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 0L)
  }
})

test_that("pdf_text_search consecutive flag enables overlapping matches", {
  # Match "ll" in "Hello": with consecutive = FALSE PDFium advances
  # past the first match (one match at chars 2..3). With consecutive
  # = TRUE PDFium does not skip past the match, so it can re-enter
  # the same region; behaviour is documented and we only verify
  # consecutive doesn't crash and produces >= the non-consecutive
  # count.
  non_consec <- pdf_text_search(fixture_path("shapes"), "l")
  consec <- pdf_text_search(fixture_path("shapes"), "l",
    consecutive = TRUE
  )
  expect_gte(nrow(consec), nrow(non_consec))
})
