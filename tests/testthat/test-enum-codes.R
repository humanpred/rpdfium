# Tests for the Phase 9 bidirectional enum-code helpers in
# R/enum_codes.R. Each enum gets a code -> name round-trip and an
# error-tolerance check (NA / unknown names; out-of-range codes).
# The tables themselves live next to each consumer (.pdfium_annot_subtypes
# in R/annotations.R, .pdfium_obj_type_names in R/classes.R, etc.).

# Annot subtype ----------------------------------------------------

test_that("pdfium_annot_subtype_name maps codes to known strings", {
  expect_identical(pdfium_annot_subtype_name(c(1L, 2L, 9L)),
                   c("text", "link", "highlight"))
  expect_identical(pdfium_annot_subtype_name(0L), "unknown")
})

test_that("pdfium_annot_subtype_code is case-insensitive", {
  expect_identical(
    pdfium_annot_subtype_code(c("text", "Link", "FILEATTACHMENT")),
    c(1L, 2L, 17L)
  )
})

test_that("pdfium_annot_subtype_code round-trips with _name", {
  codes <- 1:28
  expect_identical(
    pdfium_annot_subtype_code(pdfium_annot_subtype_name(codes)),
    codes
  )
})

test_that("pdfium_annot_subtype_code falls back to 0 on unknown", {
  expect_identical(pdfium_annot_subtype_code(NA_character_), 0L)
  expect_identical(pdfium_annot_subtype_code("nonsense"), 0L)
})

# Obj type ---------------------------------------------------------

test_that("pdfium_obj_type round-trips", {
  codes <- 0:5
  expect_identical(
    pdfium_obj_type_code(pdfium_obj_type_name(codes)),
    codes
  )
})

test_that("pdfium_obj_type_code handles bad input", {
  expect_identical(pdfium_obj_type_code(c("path", "bogus", NA)),
                   c(2L, 0L, 0L))
})

# Segment type -----------------------------------------------------

test_that("pdfium_segment_type round-trips", {
  codes <- 0:2
  expect_identical(
    pdfium_segment_type_code(pdfium_segment_type_name(codes)),
    codes
  )
  expect_identical(
    pdfium_segment_type_name(c(0L, 1L, 2L)),
    c("lineto", "bezierto", "moveto")
  )
})

# Form-field type --------------------------------------------------

test_that("pdfium_form_field_type round-trips", {
  codes <- 0:15
  expect_identical(
    pdfium_form_field_type_code(pdfium_form_field_type_name(codes)),
    codes
  )
})

test_that("pdfium_form_field_type_code accepts case variations", {
  expect_identical(
    pdfium_form_field_type_code(c("Checkbox", "TEXTFIELD")),
    c(2L, 6L)
  )
})

# Action type (1-based enum) ---------------------------------------

test_that("pdfium_action_type round-trips on 1..5", {
  codes <- 1:5
  expect_identical(
    pdfium_action_type_code(pdfium_action_type_name(codes)),
    codes
  )
})

test_that("pdfium_action_type_name returns 'unsupported' for 0", {
  expect_identical(pdfium_action_type_name(0L), "unsupported")
})

test_that("pdfium_action_type_code returns 0 for unknown", {
  expect_identical(pdfium_action_type_code("unsupported"), 0L)
  expect_identical(pdfium_action_type_code("nonsense"), 0L)
  expect_identical(pdfium_action_type_code(NA_character_), 0L)
})

# Dest view (1-based enum) -----------------------------------------

test_that("pdfium_dest_view round-trips on 1..8", {
  codes <- 1:8
  expect_identical(
    pdfium_dest_view_code(pdfium_dest_view_name(codes)),
    codes
  )
  expect_identical(pdfium_dest_view_name(0L), "unknown")
})

test_that("pdfium_dest_view_code returns 0 for unknown / NA", {
  expect_identical(pdfium_dest_view_code("nonsense"), 0L)
  expect_identical(pdfium_dest_view_code(NA), 0L)
})

# Mixed-length / NA cases ------------------------------------------

test_that("enum decoders handle empty input", {
  expect_identical(pdfium_obj_type_name(integer(0)), character(0))
  expect_identical(pdfium_obj_type_code(character(0)), integer(0))
})

test_that("enum decoders preserve input length", {
  expect_length(pdfium_annot_subtype_name(1:10), 10L)
  expect_length(pdfium_annot_subtype_code(rep("text", 7L)), 7L)
})
