test_that("pdf_page_objects returns a list of pdfium_obj", {
  # Cairo's blank page from minimal.pdf produces a single page-bounds
  # path. That's a useful smoke-test for the typical (non-empty) shape.
  pdf <- fixture_path("minimal")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  expect_type(objs, "list")
  for (o in objs) expect_s3_class(o, "pdfium_obj")
})

test_that("pdf_page_objects enumerates path + text on the shapes fixture", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

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
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  objs <- pdf_page_objects(doc)
  expect_true(length(objs) > 0L)
})

test_that("pdf_page_objects validates inputs and closed-page state", {
  expect_error(pdf_page_objects("not a page"),
               "must be a `pdfium_page` or `pdfium_doc`")

  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(try(pdf_close(doc), silent = TRUE), add = TRUE)

  page <- pdf_load_page(doc, 1)
  pdf_close_page(page)
  expect_error(pdf_page_objects(page), "Page has been closed")
})

test_that("pdf_obj_type returns the cached type and validates input", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  on.exit(pdf_close_page(page), add = TRUE, after = FALSE)

  objs <- pdf_page_objects(page)
  for (o in objs) {
    expect_identical(pdf_obj_type(o), o$type)
    expect_true(o$type %in% c("path", "text", "image", "form",
                              "shading", "unknown"))
  }

  expect_error(pdf_obj_type("not an obj"), "must be a `pdfium_obj`")
})

test_that("pdf_obj_type refuses objects whose parent page has closed", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  objs <- pdf_page_objects(page)
  pdf_close_page(page)
  expect_error(pdf_obj_type(objs[[1]]), "Parent page has been closed")
})

test_that("pdfium_obj prints/format reflect open/closed parent state", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(try(pdf_close(doc), silent = TRUE), add = TRUE)

  page <- pdf_load_page(doc, 1)
  objs <- pdf_page_objects(page)
  obj <- objs[[1]]
  expect_match(format(obj), "open")
  expect_match(format(obj), sprintf("%s, obj %d on page", obj$type, obj$index))
  expect_output(print(obj), "pdfium_obj")
  pdf_close_page(page)
  expect_match(format(obj), "closed")
})

test_that("object back-reference keeps parent page alive after rm(page)", {
  pdf <- fixture_path("shapes")
  doc <- pdf_open(pdf)
  on.exit(pdf_close(doc), add = TRUE)

  page <- pdf_load_page(doc, 1)
  obj <- pdf_page_objects(page)[[1]]
  rm(page); invisible(gc(verbose = FALSE))
  # Page externalptr is held alive via obj$ptr's prot slot, so the
  # type query must still work on the obj.
  expect_match(pdf_obj_type(obj), "^(path|text|image|form|shading|unknown)$")
})

test_that("unknown type codes map to 'unknown' safely", {
  expect_identical(pdfium:::pdfium_obj_type_name(99L),  "unknown")
  expect_identical(pdfium:::pdfium_obj_type_name(-1L),  "unknown")
  expect_identical(pdfium:::pdfium_obj_type_name(0L),   "unknown")
  expect_identical(pdfium:::pdfium_obj_type_name(2L),   "path")
})
