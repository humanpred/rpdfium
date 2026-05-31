# Install PDFium's unsupported-feature event handler

Wraps `FSDK_SetUnSpObjProcessHandler`. After installation, PDFium
buffers a string per "feature not supported" event it encounters while
parsing or rendering a document — XFA forms, custom encryption types, 3D
/ movie / sound annotations, signature annotations, and so on. The
buffer is drained with
[`pdf_drain_unsupported_features()`](https://humanpred.github.io/rpdfium/reference/pdf_drain_unsupported_features.md).

## Usage

``` r
pdf_install_unsupported_handler()
```

## Value

Invisibly returns `TRUE`.

## Details

This is opt-in. Without installing the handler, PDFium silently produces
a partial render when it can't fully process a document and rpdfium
emits no diagnostic. Installing the handler lets callers detect "did my
PDF have anything PDFium couldn't render" before relying on the result.

Installation is process-global. Once installed, the handler stays active
for the lifetime of the R session and affects every `pdfium_doc` opened
— there's no per-doc scope.

## See also

[`pdf_drain_unsupported_features()`](https://humanpred.github.io/rpdfium/reference/pdf_drain_unsupported_features.md)
to read and clear the buffer.

## Examples

``` r
pdf_install_unsupported_handler()
doc <- pdf_doc_open(system.file("extdata", "fixtures", "shapes.pdf",
                                 package = "pdfium"))
pdf_drain_unsupported_features()  # character(0) -- nothing flagged
#> character(0)
pdf_doc_close(doc)
```
