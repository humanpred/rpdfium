# Read every page's text in one call

Convenience wrapper that returns the document's text content one string
per page, matching the shape of `pdftools::pdf_text()`. Each element is
the concatenated text of every text run on the corresponding page,
joined with `"\n"` between runs.

## Usage

``` r
pdf_text(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

Character vector of length `pdf_page_count(doc)`. Each element is UTF-8
encoded.

## Details

Internally walks the document with
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
to reuse the batched text-page load.

## See also

[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
for run-level structure (font, bounding box).

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) pdf_text(fixture)
#> [1] "Hello"
```
