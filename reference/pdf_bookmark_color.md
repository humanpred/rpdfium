# Bookmark title color

Returns the color a viewer should use for the bookmark's title (the
outline item's `/C` entry, ISO 32000-1:2008 Table 153). Wraps
`FPDFBookmark_GetColor`.

## Usage

``` r
pdf_bookmark_color(bm)
```

## Arguments

- bm:

  A `pdfium_bookmark` handle from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).

## Value

Named numeric `c(red, green, blue)` with components in `[0, 1]`, the
same scale as
[`pdf_annot_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_color.md).
All `NA` when the bookmark has no `/C` entry, or its `/C` is not three
numbers in `[0, 1]`.

## See also

[`pdf_bookmark_style()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_style.md);
the `color_*` columns of `as_tibble(pdf_doc_bookmarks(doc))`.
