# Bookmark action type

Returns one of `"goto"`, `"remote_goto"`, `"uri"`, `"launch"`,
`"embedded_goto"`, or `"unsupported"`. Wraps `FPDFAction_GetType`.

## Usage

``` r
pdf_bookmark_action_type(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md).

## Value

Character scalar.
