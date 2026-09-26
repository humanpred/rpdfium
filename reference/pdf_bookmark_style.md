# Bookmark title style

Returns whether a viewer should draw the bookmark's title in italic
and/or bold (the outline item's `/F` flags, ISO 32000-1:2008 Table 154).
Wraps `FPDFBookmark_GetStyle`.

## Usage

``` r
pdf_bookmark_style(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).

## Value

Named logical `c(italic, bold)`; both `FALSE` when the bookmark declares
no style.

## See also

[`pdf_bookmark_color()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_color.md);
the `italic` / `bold` columns of `as_tibble(pdf_doc_bookmarks(doc))`.
