# Bookmark destination zoom factor

Returns the zoom factor for XYZ destinations; `NA` for view modes that
don't carry one. Wraps `FPDFDest_GetLocationInPage`.

## Usage

``` r
pdf_bookmark_dest_zoom(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).

## Value

Numeric scalar or `NA`.
