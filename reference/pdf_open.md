# Open a PDF document

Loads a PDF file from disk. The returned `pdfium_doc` carries an
external pointer to a PDFium `FPDF_DOCUMENT` handle along with a
finalizer that calls `FPDF_CloseDocument()` when the R object is
garbage-collected. Call
[`pdf_close()`](https://humanpred.github.io/rpdfium/reference/pdf_close.md)
explicitly when you need deterministic release.

## Usage

``` r
pdf_open(path, password = NULL)
```

## Arguments

- path:

  Character scalar. Path to a PDF file. The file must exist and be
  readable.

- password:

  Optional password for encrypted PDFs. `NULL` (the default) passes no
  password to PDFium, which works for both unencrypted documents and the
  rare case of empty-string-password encryption. Provide a string when
  the document requires it. Future minor releases will broaden support
  for password-protected PDFs; the parameter is present in v0.1.0 to
  reserve the signature.

## Value

A `pdfium_doc` object.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  pdf_page_count(doc)
  pdf_close(doc)
}
```
