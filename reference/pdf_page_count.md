# Count pages in a PDF document

Returns the number of pages in `doc`. Accepts either an open
`pdfium_doc` or a character path (in which case it opens and closes the
document internally — convenient for one-shot inspection).

## Usage

``` r
pdf_page_count(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character scalar path.

## Value

An integer scalar — the page count.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  pdf_page_count(fixture)
}
#> [1] 1
```
