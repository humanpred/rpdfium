# Import page ranges from a source doc into a destination doc

Wraps `FPDF_ImportPages` — the string-range variant of
[`pdf_docs_merge()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_docs_merge.md).
Takes a comma-separated range like `"1-3,5,7-10"` instead of an integer
vector.

## Usage

``` r
pdf_docs_import_pages(dest_doc, src_doc, range = "", at = NULL)
```

## Arguments

- dest_doc:

  A `pdfium_doc` opened with `readwrite = TRUE`.

- src_doc:

  Source `pdfium_doc`.

- range:

  Character — the page range. Empty string `""` (the default) imports
  every page.

- at:

  One-based insertion index in `dest_doc`. Defaults to the end (use
  `pdf_page_count(dest_doc) + 1`).

## Value

Invisibly returns `dest_doc`.

## See also

[`pdf_docs_merge()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_docs_merge.md)
for the integer-vector variant.
