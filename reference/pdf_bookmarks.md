# Read the bookmark outline (table of contents) of a PDF

Returns a tibble row per bookmark, walking PDFium's outline tree
depth-first. Each row carries the bookmark's title, its position in the
hierarchy, and the page it points to (or `NA` when the bookmark uses an
action — URI, launch — rather than a destination).

## Usage

``` r
pdf_bookmarks(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

## Value

A tibble with columns:

- `bookmark_index` integer - 1-based pre-order index across the entire
  outline tree.

- `parent_index` integer - `bookmark_index` of the parent entry, or `0`
  for top-level bookmarks.

- `level` integer - 1-based nesting depth.

- `title` character - the bookmark's display text, UTF-8.

- `page_num` integer - 1-based destination page number, or `NA` when the
  bookmark has no page destination.

Returns a 0-row tibble of the same schema when the document has no
outline.

## Details

The tree structure is recoverable from the `parent_index` column alone:
top-level bookmarks have `parent_index == 0`, and every other bookmark's
parent is the row whose `bookmark_index` matches its `parent_index`. The
`level` column is a convenience for filtering ("show me chapter-level
entries only").

Wraps `FPDFBookmark_GetFirstChild`, `FPDFBookmark_GetNextSibling`,
`FPDFBookmark_GetTitle`, `FPDFBookmark_GetDest`, and
`FPDFDest_GetDestPageIndex`.

## See also

[`pdf_page_labels()`](https://humanpred.github.io/rpdfium/reference/pdf_page_labels.md)
for logical page numbering.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) pdf_bookmarks(fixture)
#> # A tibble: 0 × 5
#> # ℹ 5 variables: bookmark_index <int>, parent_index <int>, level <int>,
#> #   title <chr>, page_num <int>
```
