# Save a PDF document to disk

Serialises an in-memory `pdfium_doc` (typically produced by
[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md)
with `readwrite = TRUE` and one or more mutators) to a file. Wraps
`FPDF_SaveAsCopy` and `FPDF_SaveWithVersion`.

## Usage

``` r
pdf_save(
  doc,
  file,
  incremental = FALSE,
  remove_security = FALSE,
  subset_new_fonts = TRUE,
  version = NULL
)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md)
  or
  [`pdf_doc_new()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_new.md).

- file:

  Destination path. The directory must exist.

- incremental:

  Logical. If `TRUE`, append an incremental update preserving the
  original byte layout (required for signed-PDF workflows). If `FALSE`
  (default), rewrite the whole file.

- remove_security:

  Logical. If `TRUE`, strip the encryption dictionary from the saved
  copy. Defaults `FALSE`. Use with caution.

- subset_new_fonts:

  Logical. If `TRUE` (default), subset newly-embedded fonts the same way
  Acrobat does. Set `FALSE` to embed full font tables.

- version:

  Integer or `NULL`. The PDF version in PDFium's "10 \* major + minor"
  form (e.g. `17` for PDF 1.7). `NULL` (default) preserves the input
  file's declared version.

## Value

Invisibly returns `file`, the path written to.

## Details

`pdf_save()` writes atomically: PDFium's bytes go into a tempfile in the
destination directory, and on success the tempfile is renamed over
`file`. If the save fails mid-write, the original `file` (if any) is
preserved untouched.

Works on read-only documents too — opening a PDF, calling `pdf_save()`,
and re-opening the result is a way to "normalise" a PDF (rebuild the
xref table, etc.) without modifying its content.

## See also

[`pdf_save_to_raw()`](https://humanpred.github.io/rpdfium/reference/pdf_save_to_raw.md)
for in-memory output;
[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md)
for the read side;
[`pdf_doc_new()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_new.md)
for a fresh document.
