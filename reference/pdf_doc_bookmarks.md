# Read the bookmark outline (table of contents) of a PDF

Returns a tibble row per bookmark, walking PDFium's outline tree
depth-first. Each row carries the bookmark's title, its position in the
hierarchy, the page it points to (when resolvable), and the action it
carries (URI, launch, remote_goto, embedded_goto, or the typical
goto-within-this-document).

## Usage

``` r
pdf_doc_bookmarks(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
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
  bookmark has no resolvable page destination (e.g. for URI / launch
  actions, or unresolvable dests).

- `action_type` character - one of `"goto"`, `"remote_goto"`, `"uri"`,
  `"launch"`, `"embedded_goto"`.

- `uri` character - the action's target URL when `action_type == "uri"`;
  `NA` otherwise.

- `filepath` character - the external file path when `action_type` is
  `"remote_goto"` / `"launch"` / `"embedded_goto"`; `NA` otherwise.

- `dest_view` character - the destination view mode (one of `"xyz"`,
  `"fit"`, `"fith"`, `"fitv"`, `"fitr"`, `"fitb"`, `"fitbh"`, `"fitbv"`,
  `"unknown"`).

- `dest_x`, `dest_y`, `dest_zoom` numeric - the explicit point / zoom
  for XYZ destinations and the line offset for FitH / FitV / FitBH /
  FitBV. `NA` for components the destination doesn't specify.

Returns a 0-row tibble of the same schema when the document has no
outline.

## Details

The tree structure is recoverable from the `parent_index` column alone:
top-level bookmarks have `parent_index == 0`, and every other bookmark's
parent is the row whose `bookmark_index` matches its `parent_index`. The
`level` column is a convenience for filtering ("show me chapter-level
entries only").

Wraps `FPDFBookmark_GetFirstChild`, `FPDFBookmark_GetNextSibling`,
`FPDFBookmark_GetTitle`, `FPDFBookmark_GetDest`,
`FPDFBookmark_GetAction`, `FPDFAction_GetType` / `FPDFAction_GetURIPath`
/ `FPDFAction_GetFilePath`, and `FPDFDest_GetDestPageIndex`.

## See also

[`pdf_page_labels()`](https://humanpred.github.io/rpdfium/reference/pdf_page_labels.md)
for logical page numbering,
[`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md)
for clickable link annotations on a page.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "outline.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) pdf_doc_bookmarks(fixture)
#> # A tibble: 3 × 12
#>   bookmark_index parent_index level title    page_num action_type uri   filepath
#>            <int>        <int> <int> <chr>       <int> <chr>       <chr> <chr>   
#> 1              1            0     1 Chapter…        1 goto        NA    NA      
#> 2              2            1     2 Section…        1 goto        NA    NA      
#> 3              3            1     2 Section…        2 goto        NA    NA      
#> # ℹ 4 more variables: dest_view <chr>, dest_x <dbl>, dest_y <dbl>,
#> #   dest_zoom <dbl>
```
