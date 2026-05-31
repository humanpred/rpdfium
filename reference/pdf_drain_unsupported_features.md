# Read and clear the PDFium unsupported-feature event buffer

Returns the human-readable feature names PDFium has flagged as
unsupported since the previous call (or since the handler was installed
via
[`pdf_install_unsupported_handler()`](https://humanpred.github.io/rpdfium/reference/pdf_install_unsupported_handler.md)).
The buffer is cleared on read.

## Usage

``` r
pdf_drain_unsupported_features()
```

## Value

Character vector of feature names. Each entry is a human- readable
string drawn from the `FPDF_UNSP_*` enum, e.g. `"XFA form"`,
`"3D annotation"`, `"document security"`, `"signature annotation"`.
Possibly contains duplicates if a feature was flagged multiple times.

## Details

Returns `character(0)` when nothing has been flagged or when the handler
is not installed (no events are buffered until installation).

## See also

[`pdf_install_unsupported_handler()`](https://humanpred.github.io/rpdfium/reference/pdf_install_unsupported_handler.md)
to enable the handler.

## Examples

``` r
pdf_install_unsupported_handler()
doc <- pdf_doc_open(system.file("extdata", "fixtures", "shapes.pdf",
                                 package = "pdfium"))
pdf_drain_unsupported_features()  # character(0) -- nothing flagged
#> character(0)
pdf_doc_close(doc)
```
