# Open a PDF document

Loads a PDF from disk or from an in-memory byte buffer. The returned
`pdfium_doc` carries an external pointer to a PDFium `FPDF_DOCUMENT`
handle along with a finalizer that calls `FPDF_CloseDocument()` when the
R object is garbage-collected. Call
[`pdf_doc_close()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_close.md)
explicitly when you need deterministic release.

## Usage

``` r
pdf_doc_open(path = NULL, source = NULL, password = NULL, readwrite = FALSE)
```

## Arguments

- path:

  Character scalar. Path to a PDF file. The file must exist and be
  readable. Mutually exclusive with `source`.

- source:

  Raw vector containing the PDF byte stream. PDFium keeps an internal
  reference to the bytes for the document's lifetime, so the wrapper
  makes its own copy on the C++ side and releases it when the
  `pdfium_doc` is garbage-collected. Mutually exclusive with `path`.

- password:

  Optional password for encrypted PDFs. `NULL` (the default) passes no
  password to PDFium.

- readwrite:

  Logical. If `TRUE`, the document is opened in read-write mode and
  every mutator function
  ([`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md),
  [`pdf_page_set_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_set_rotation.md),
  the `pdf_*_set_*()` family, annotation authoring, form filling, …)
  will accept it. Defaults `FALSE` — a read-only handle that refuses
  mutations with a clear error message. See ADR-012 in `dev/decisions/`.
  PDFium itself has no read/write distinction; the flag is the R
  wrapper's safety net against accidental edits inside long pipelines.

## Value

A `pdfium_doc` object.

## Details

Two input forms are supported. Pass `path` to load from disk (via
PDFium's `FPDF_LoadDocument`), or pass `source` for an in-memory raw
vector (via `FPDF_LoadMemDocument64`). The in-memory path is useful for
documents downloaded via
[`httr2::resp_body_raw()`](https://httr2.r-lib.org/reference/resp_body_raw.html),
[`curl::curl_fetch_memory()`](https://jeroen.r-universe.dev/curl/reference/curl_fetch.html),
or read with [`readBin()`](https://rdrr.io/r/base/readBin.html) straight
into RAM. Exactly one of `path` or `source` must be provided.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  pdf_page_count(doc)
  pdf_doc_close(doc)
}

# Round-trip via raw bytes - useful for downloaded PDFs.
if (nzchar(fixture)) {
  bytes <- readBin(fixture, "raw", file.info(fixture)$size)
  doc <- pdf_doc_open(source = bytes)
  pdf_page_count(doc)
  pdf_doc_close(doc)
}
```
