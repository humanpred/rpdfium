# Byte offsets of every `%%EOF` trailer marker

Returns one integer per trailer end-of-file marker in the source bytes.
A clean single-revision PDF reports one value. Incremental updates
append additional bodies / xref tables and trailers, each marked by
another `%%EOF`. Wraps `FPDF_GetTrailerEnds`.

## Usage

``` r
pdf_doc_trailer_ends(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

## Value

Integer vector of byte offsets (one per trailer). Empty when PDFium
reports none. Returns `NA` for any offset that exceeds R's 32-bit signed
integer range (files larger than 2 GB).

## Details

Useful for incremental-update analysis, signature byte-range validation,
and PDF repair workflows.
