# Bookmark external file path

Returns the external file path when the bookmark action is
`"remote_goto"`, `"launch"`, or `"embedded_goto"`, else `NA_character_`.
Wraps `FPDFAction_GetFilePath`.

## Usage

``` r
pdf_bookmark_filepath(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md).

## Value

Character scalar or `NA`.
