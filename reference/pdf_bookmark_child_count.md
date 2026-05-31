# Number of children for a bookmark

Wraps `FPDFBookmark_GetCount` — returns the count of direct child
bookmarks under a given outline entry. Useful when you have a single
`pdfium_bookmark` handle (e.g. from
[`pdf_doc_bookmark_find()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmark_find.md))
and want to know whether it expands.

## Usage

``` r
pdf_bookmark_child_count(bookmark)
```

## Arguments

- bookmark:

  A `pdfium_bookmark` from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md)
  or
  [`pdf_doc_bookmark_find()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmark_find.md).

## Value

Integer scalar — the number of direct children. `0` if the bookmark has
no children.

## Details

The full pre-order outline (with `parent_index` columns) is available
via
[`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md);
this function is the per-handle accessor.
