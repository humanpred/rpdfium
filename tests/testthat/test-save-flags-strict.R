# Stricter assertions for the FPDF_SaveAsCopy flag values.
#
# Split out of test-mut-save.R, whose "honours ... flags" test only checks
# that a flag is *accepted without error* (its own comment notes "no
# encrypted fixture to verify behaviour"). That smoke test passes whether
# remove_security encodes to 3, 4, or 8 — so it cannot catch a wrong value.
# The tests below pin the *exact* integer each flag encodes to.
#
# Why this matters (see dev/pdfium-7857-api-delta.md §C-3): PDFium
# chromium/7857 converted the save flags to a real bitmask —
# FPDF_REMOVE_SECURITY moved 3 -> (1<<2)=4, and a new
# FPDF_SUBSET_NEW_FONTS=(1<<3)=8 was added (fpdf_save.h:46-54). R/save.R
# already encodes 4 / 8, so the values are correct under the current pin.
# But they were introduced (commit 41f348e) while the package was still
# pinned to chromium/7202, where FPDF_REMOVE_SECURITY was 3 and
# SUBSET_NEW_FONTS did not exist — so under 7202 both flags were silent
# no-ops. A value-pinning test would have surfaced that mismatch; the
# existing smoke test did not.

test_that(".pdfium_save_flags match PDFium chromium/7857 fpdf_save.h", {
  fl <- pdfium:::.pdfium_save_flags
  expect_identical(fl[["incremental"]], 1L)      # FPDF_INCREMENTAL      (1<<0)
  expect_identical(fl[["no_incremental"]], 2L)   # FPDF_NO_INCREMENTAL   (1<<1)
  expect_identical(fl[["remove_security"]], 4L)  # FPDF_REMOVE_SECURITY  (1<<2); was 3 in 7202
  expect_identical(fl[["subset_new_fonts"]], 8L) # FPDF_SUBSET_NEW_FONTS (1<<3); absent in 7202
})

test_that("encode_save_flags() produces the exact bitmask per flag combo", {
  enc <- pdfium:::encode_save_flags
  # incremental and no_incremental are mutually exclusive (PDFium forbids
  # combining them); encode_save_flags() picks no_incremental when the
  # incremental argument is false.
  expect_identical(enc(FALSE, FALSE, FALSE), 2L)   # no_incremental on its own
  expect_identical(enc(TRUE,  FALSE, FALSE), 1L)   # incremental on its own
  expect_identical(enc(FALSE, TRUE,  FALSE), 6L)   # 2 plus 4 remove-security bit
  expect_identical(enc(FALSE, FALSE, TRUE),  10L)  # 2 plus 8 subset-fonts bit
  expect_identical(enc(TRUE,  TRUE,  TRUE),  13L)  # 1 plus 4 plus 8

  # The specific values that silently regressed across the 7202-to-7857
  # bump. Each flag's marginal contribution must be its 7857 bit:
  base <- enc(FALSE, FALSE, FALSE)
  expect_identical(enc(FALSE, TRUE,  FALSE) - base, 4L)  # remove-security bit is 4, not old 3
  expect_identical(enc(FALSE, FALSE, TRUE)  - base, 8L)  # subset-new-fonts bit is 8
})

test_that("remove_security strips the /Encrypt dict (needs encrypted fixture)", {
  # FUTURE WORK: behavioural counterpart to the encode tests above — it
  # pins the *effect* of remove_security, not just the integer it encodes
  # to. It needs an encrypted/password-protected fixture that does not
  # exist yet. To make this pass:
  #   1. Add an `encrypted.pdf` fixture (e.g. owner-password, RC4 or AES)
  #      to tools/build-fixtures.R and inst/extdata/fixtures/.
  #   2. Delete the skip() below.
  # Expected: the saved copy opens without a password and its bytes carry
  # no "/Encrypt" entry.
  skip("needs an encrypted.pdf fixture (add it in tools/build-fixtures.R)")

  fx <- fixture_path("encrypted")
  doc <- pdf_doc_open(fx, password = "owner", readwrite = TRUE)
  on.exit(pdf_doc_close(doc), add = TRUE)

  raw_plain <- pdf_save_to_raw(doc, remove_security = TRUE)
  expect_false(grepl("/Encrypt", rawToChar(raw_plain), fixed = TRUE))
})
