# Bookmark destination y coordinate

Returns the Y coordinate of the destination for XYZ / FitR / FitBV
destinations; `NA` for view modes that don't carry one. Wraps
`FPDFDest_GetLocationInPage`.

## Usage

``` r
pdf_bookmark_dest_y(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md).

## Value

Numeric scalar or `NA`.
