# Bookmark URI (for URI actions)

Returns the action's target URL when the bookmark is a URI action, else
`NA_character_`. Wraps `FPDFAction_GetURIPath`.

## Usage

``` r
pdf_bookmark_uri(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).

## Value

Character scalar or `NA`.
