# Bookmark destination page number

Returns the 1-based page number the bookmark resolves to, or
`NA_integer_` when the bookmark has no resolvable in-document
destination (URI / launch actions, or unresolvable /Dest entries).

## Usage

``` r
pdf_bookmark_page_num(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).

## Value

Integer scalar (1-based) or `NA`.
