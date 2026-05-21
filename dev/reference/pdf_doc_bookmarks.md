# List the bookmark outline (table of contents) of a PDF

Returns a `pdfium_bookmark_list` — a list of `pdfium_bookmark` handles,
one per bookmark in the document's outline tree, walked depth-first.
Per-attribute getters
([`pdf_bookmark_title()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_title.md),
[`pdf_bookmark_page_num()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_page_num.md),
[`pdf_bookmark_action_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_action_type.md),
[`pdf_bookmark_uri()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_uri.md),
[`pdf_bookmark_filepath()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_filepath.md),
[`pdf_bookmark_dest_view()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_view.md),
[`pdf_bookmark_dest_x()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_x.md),
[`pdf_bookmark_dest_y()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_y.md),
[`pdf_bookmark_dest_zoom()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_zoom.md))
operate on a single handle.

## Usage

``` r
pdf_doc_bookmarks(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

## Value

A `pdfium_bookmark_list` (empty if no outline).

## Details

The list is flat; the tree shape is recovered from each handle's
`parent_index` field. Top-level bookmarks have `parent_index == 0`;
every other bookmark's parent is the entry whose `index` matches its
`parent_index`. `level` is the 1-based nesting depth.

Use `tibble::as_tibble(pdf_doc_bookmarks(doc))` for the tibble view.

Wraps `FPDFBookmark_GetFirstChild`, `FPDFBookmark_GetNextSibling`,
`FPDFBookmark_GetTitle`, `FPDFBookmark_GetDest`,
`FPDFBookmark_GetAction`, `FPDFAction_GetType` / `FPDFAction_GetURIPath`
/ `FPDFAction_GetFilePath`, and `FPDFDest_GetDestPageIndex`.

## See also

[`pdf_page_labels()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_labels.md)
for logical page numbering,
[`pdf_page_links()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_links.md)
for clickable link annotations on a page,
[`pdf_parse_date()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_parse_date.md)
for parsing date-shaped action strings.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "outline.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) pdf_doc_bookmarks(fixture)
#> <pdfium_bookmark_list: 3 bookmark(s)>
#>   [[1]] <pdfium_bookmark [open] Chapter 1, idx 1, level 1>
#>   [[2]] <pdfium_bookmark [open] Section 1.1, idx 2, level 2>
#>   [[3]] <pdfium_bookmark [open] Section 1.2, idx 3, level 2>
```
