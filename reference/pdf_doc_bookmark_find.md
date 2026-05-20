# Find a bookmark by its title

Returns the matching `pdfium_bookmark` handle, or `NULL` when no outline
entry matches `title`. The returned handle is usable with every
per-attribute getter
([`pdf_bookmark_title()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_title.md),
[`pdf_bookmark_page_num()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_page_num.md),
...) and can be slotted back into
[`as_pdfium_bookmark_list()`](https://humanpred.github.io/rpdfium/reference/as_pdfium_bookmark_list.md)
with other handles. Wraps `FPDFBookmark_Find` plus a pre-order walk to
recover the structural `index` / `parent_index` / `level` fields.

## Usage

``` r
pdf_doc_bookmark_find(doc, title, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

- title:

  Single non-empty character string.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A `pdfium_bookmark` handle, or `NULL` when no match.

## Details

PDFium's matching is case-sensitive and matches the full title string.

## See also

[`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md),
[`pdf_bookmark_title()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_title.md).
