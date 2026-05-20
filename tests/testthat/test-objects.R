test_that("pdf_page_objects returns a pdfium_obj_list", {
  # Cairo's blank page from minimal.pdf produces a single page-bounds
  # path. That's a useful smoke-test for the typical (non-empty) shape.
  pdf <- fixture_path("minimal")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  expect_s3_class(objs, "pdfium_obj_list")
  expect_type(objs, "list")
  for (o in objs) expect_s3_class(o, "pdfium_obj")
})

test_that("pdf_page_objects tibble view carries bbox + flag columns + handle/source", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  tbl <- tibble::as_tibble(pdf_page_objects(page))
  expect_s3_class(tbl, "tbl_df")
  expect_named(tbl, c(
    "object_index", "type", "bbox_left", "bbox_bottom",
    "bbox_right", "bbox_top", "has_transparency", "is_active",
    "parent_form_index", "handle", "source"
  ))
  expect_gt(nrow(tbl), 0L)
  expect_type(tbl$object_index, "integer")
  expect_type(tbl$type, "character")
  expect_type(tbl$bbox_left, "double")
  expect_type(tbl$has_transparency, "logical")
  expect_type(tbl$is_active, "logical")
  expect_true(all(is.na(tbl$parent_form_index)))
})

test_that("pdf_page_objects tibble view is empty for an empty page", {
  doc <- pdf_doc_new()
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_new(doc, page_num = 1L, width = 100, height = 100)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  expect_s3_class(objs, "pdfium_obj_list")
  expect_length(objs, 0L)
  tbl <- tibble::as_tibble(objs)
  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 0L)
  expect_named(tbl, c(
    "object_index", "type", "bbox_left", "bbox_bottom",
    "bbox_right", "bbox_top", "has_transparency", "is_active",
    "parent_form_index", "handle", "source"
  ))
})

test_that("as_pdfium_obj_list round-trips from tibble", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  tbl <- tibble::as_tibble(objs)
  back <- as_pdfium_obj_list(tbl)
  expect_s3_class(back, "pdfium_obj_list")
  expect_identical(back[[1L]]$ptr, objs[[1L]]$ptr)
})

test_that("as_pdfium_obj_list is a no-op on existing wrappers", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  expect_identical(as_pdfium_obj_list(objs), objs)
})

test_that("as_pdfium_obj_list accepts a plain list of handles", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  plain <- unclass(objs)
  back <- as_pdfium_obj_list(plain)
  expect_s3_class(back, "pdfium_obj_list")
})

test_that("as_pdfium_obj_list errors on unrecognised input", {
  expect_error(as_pdfium_obj_list("nope"),
               "must be a .pdfium_obj_list.")
  expect_error(
    as_pdfium_obj_list(tibble::tibble(handle = list(),
                                       source = list())),
    "zero-row"
  )
})

test_that("pdfium_obj_list print shows count and entries", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)
  objs <- pdf_page_objects(page)
  txt <- capture.output(print(objs))
  expect_true(any(grepl(sprintf("%d object\\(s\\)", length(objs)), txt)))
})

test_that("pdf_page_objects enumerates path + text on the shapes fixture", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  expect_type(objs, "list")
  expect_gt(length(objs), 0L)

  types <- vapply(objs, function(o) o$type, character(1))
  # build-fixtures.R draws four path operations (rect + 2 line segments)
  # and one text run. Cairo may emit additional path-fill operations
  # for the rectangle, so we assert ranges rather than exact counts.
  expect_true("path" %in% types)
  expect_true("text" %in% types)
  expect_equal(sum(types == "text"), 1L)
  expect_gte(sum(types == "path"), 2L)
})

test_that("pdf_page_objects accepts a doc (auto-loads page 1)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  objs <- pdf_page_objects(doc)
  expect_true(length(objs) > 0L)
})

test_that("pdf_page_objects validates inputs and closed-page state", {
  expect_error(
    pdf_page_objects("not a page"),
    "class .pdfium_page./.pdfium_doc."
  )

  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(try(pdf_doc_close(doc), silent = TRUE), add = TRUE)

  page <- pdf_page_load(doc, 1)
  pdf_page_close(page)
  expect_error(pdf_page_objects(page), "Page has been closed")
})

test_that("pdf_obj_type returns the cached type and validates input", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  for (o in objs) {
    expect_identical(pdf_obj_type(o), o$type)
    expect_true(o$type %in% c(
      "path", "text", "image", "form",
      "shading", "unknown"
    ))
  }

  expect_error(pdf_obj_type("not an obj"), "class .pdfium_obj.")
})

test_that("pdf_obj_type refuses objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  objs <- pdf_page_objects(page)
  pdf_page_close(page)
  expect_error(pdf_obj_type(objs[[1]]), "Parent page has been closed")
})

test_that("pdfium_obj prints/format reflect open/closed parent state", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(try(pdf_doc_close(doc), silent = TRUE), add = TRUE)

  page <- pdf_page_load(doc, 1)
  objs <- pdf_page_objects(page)
  obj <- objs[[1]]
  expect_match(format(obj), "open")
  expect_match(format(obj), sprintf("%s, obj %d on page", obj$type, obj$index))
  expect_output(print(obj), "pdfium_obj")
  pdf_page_close(page)
  expect_match(format(obj), "closed")
})

test_that("object back-reference keeps parent page alive after rm(page)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  obj <- pdf_page_objects(page)[[1]]
  rm(page)
  invisible(gc(verbose = FALSE))
  # Page externalptr is held alive via obj$ptr's prot slot, so the
  # type query must still work on the obj.
  expect_match(pdf_obj_type(obj), "^(path|text|image|form|shading|unknown)$")
})

test_that("unknown type codes map to 'unknown' safely", {
  expect_identical(pdfium:::pdfium_obj_type_name(99L), "unknown")
  expect_identical(pdfium:::pdfium_obj_type_name(-1L), "unknown")
  expect_identical(pdfium:::pdfium_obj_type_name(0L), "unknown")
  expect_identical(pdfium:::pdfium_obj_type_name(2L), "path")
})

test_that("pdf_obj_bounds returns a 4-element named numeric vector", {
  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)

  page <- pdf_page_load(doc, 1)
  on.exit(pdf_page_close(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  for (o in objs) {
    b <- pdf_obj_bounds(o)
    expect_named(b, c("left", "bottom", "right", "top"))
    expect_type(b, "double")
    expect_true(b[["right"]] >= b[["left"]])
    expect_true(b[["top"]] >= b[["bottom"]])
  }

  # The Cairo-built rectangle in shapes.pdf is the second path object;
  # it covers ~(44, 41) - (177, 175) in points. Assert the right-left
  # width and top-bottom height roughly match the user-space size
  # passed to graphics::rect (2.0 x 2.0 in user coords = 144 x 144 in
  # points within a 288x216-point page).
  rect_obj <- objs[[2]]
  rect_bounds <- pdf_obj_bounds(rect_obj)
  expect_equal(rect_bounds[["right"]] - rect_bounds[["left"]],
    144,
    tolerance = 1
  )
  expect_equal(rect_bounds[["top"]] - rect_bounds[["bottom"]],
    144,
    tolerance = 1
  )
})

test_that("pdf_obj_bounds validates inputs and closed-page state", {
  expect_error(pdf_obj_bounds("not an obj"), "class .pdfium_obj.")

  pdf <- fixture_path("shapes")
  doc <- pdf_doc_open(pdf)
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1)
  objs <- pdf_page_objects(page)
  pdf_page_close(page)
  expect_error(
    pdf_obj_bounds(objs[[1]]),
    "Parent page has been closed"
  )
})
