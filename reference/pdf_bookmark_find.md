# Find a bookmark by its title

Returns the 1-based `bookmark_index` of the first outline entry matching
`title`, suitable for indexing back into
[`pdf_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmarks.md)'s
tibble. `NA` when no bookmark matches. Wraps `FPDFBookmark_Find` and
walks the outline pre-order to map the PDFium handle back to the row
index.

## Usage

``` r
pdf_bookmark_find(doc, title, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- title:

  Single non-empty character string.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

Integer scalar — the 1-based bookmark_index, or `NA`.

## Details

PDFium's matching is case-sensitive and matches the full title string.

## See also

[`pdf_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmarks.md).
