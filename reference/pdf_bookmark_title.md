# Bookmark display title

Returns the bookmark's display text (UTF-8). Wraps
`FPDFBookmark_GetTitle`.

## Usage

``` r
pdf_bookmark_title(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).

## Value

Character scalar.
