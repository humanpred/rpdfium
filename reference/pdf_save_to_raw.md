# Save a PDF document to a raw vector

Like
[`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md)
but returns the saved PDF's bytes as a `raw` vector instead of writing
to disk. Useful for piping the serialised PDF directly into another
consumer
([`httr2::req_body_raw()`](https://httr2.r-lib.org/reference/req_body.html),
`aws.s3::put_object()`, etc.).

## Usage

``` r
pdf_save_to_raw(
  doc,
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

A `raw` vector containing the saved PDF.

## See also

[`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md)
for disk output.
