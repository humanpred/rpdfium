# Open a PDF document from a URL

Convenience wrapper around
[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md)
that fetches the bytes of a remote (or `file://`) URL via base R's
[`url()`](https://rdrr.io/r/base/connections.html) +
[`readBin()`](https://rdrr.io/r/base/readBin.html) and loads the result
through PDFium's in-memory path (`FPDF_LoadMemDocument64`). No temporary
file is left on disk; the bytes live in R memory for the document's
lifetime.

## Usage

``` r
pdf_doc_open_url(url, password = NULL, readwrite = FALSE)
```

## Arguments

- url:

  Character scalar. Must start with one of `http://`, `https://`,
  `ftp://`, or `file://`.

- password:

  Optional password for encrypted PDFs. `NULL` (the default) passes no
  password to PDFium.

- readwrite:

  Logical. As for
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md).

## Value

A `pdfium_doc`.

## Details

Network errors propagate from
[`url()`](https://rdrr.io/r/base/connections.html) /
[`readBin()`](https://rdrr.io/r/base/readBin.html) (typical shape:
`cannot open URL '...'` from `connection failed`). The returned
`pdfium_doc`'s `$path` field is the URL string itself, so
[`print()`](https://rdrr.io/r/base/print.html) and
[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
surface the source even though no local path exists.

## See also

[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md)
for the doc-open primitive.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open_url(paste0("file://", fixture))
  pdf_page_count(doc)
  pdf_doc_close(doc)
}
```
