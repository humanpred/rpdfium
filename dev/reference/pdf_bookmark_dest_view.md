# Bookmark destination view mode

Returns the destination view mode (one of `"xyz"`, `"fit"`, `"fith"`,
`"fitv"`, `"fitr"`, `"fitb"`, `"fitbh"`, `"fitbv"`, `"unknown"`). Wraps
`FPDFDest_GetView`.

## Usage

``` r
pdf_bookmark_dest_view(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md).

## Value

Character scalar.
