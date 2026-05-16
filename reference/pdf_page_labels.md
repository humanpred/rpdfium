# Read every page's logical label in one call

Convenience wrapper that calls
[`pdf_page_label()`](https://humanpred.github.io/rpdfium/reference/pdf_page_label.md)
for every page of the document and returns the results as a character
vector (positionally aligned: element `i` is the label of page `i`).

## Usage

``` r
pdf_page_labels(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

## Value

Character vector of length `pdf_page_count(doc)`.

## See also

[`pdf_page_label()`](https://humanpred.github.io/rpdfium/reference/pdf_page_label.md)
for a single page.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) pdf_page_labels(fixture)
#> [1] ""
```
