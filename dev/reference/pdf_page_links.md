# List the clickable links on a page

Returns one tibble row per link annotation on the page, with the link's
bounding rectangle and the action it carries (target page for internal
links, URL for external links). Wraps `FPDFLink_Enumerate` plus the
per-link `FPDFLink_GetAnnotRect`, `FPDFLink_GetAction` / `_GetDest`,
`FPDFAction_GetType`, `FPDFAction_GetURIPath`, `FPDFAction_GetFilePath`,
and `FPDFDest_GetDestPageIndex`.

## Usage

``` r
pdf_page_links(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with columns:

- `link_index` integer - 1-based position in the page's link table.

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` - link
  hit-test rectangle in PDF user space.

- `action_type` character - one of `"goto"` (jump within the document),
  `"remote_goto"` (jump to a remote PDF), `"uri"` (open a URL),
  `"launch"` (launch an external file or application), `"embedded_goto"`
  (jump into an embedded file), or `"unsupported"`.

- `uri` character - the target URL when `action_type == "uri"`; `NA`
  otherwise.

- `filepath` character - the external file path when `action_type` is
  `"remote_goto"` / `"launch"` / `"embedded_goto"`; `NA` otherwise.

- `dest_page_num` integer - 1-based destination page within the current
  (or remote) document; `NA` when not resolvable.

- `dest_view` character - destination view mode (`"xyz"`, `"fit"`,
  `"fith"`, `"fitv"`, `"fitr"`, `"fitb"`, `"fitbh"`, `"fitbv"`,
  `"unknown"`).

- `dest_x`, `dest_y`, `dest_zoom` numeric - explicit point and zoom for
  XYZ destinations / scroll offsets for the Fit\* variants; `NA` for
  components the destination doesn't set.

- `quad_points` list-column - per-line quad sets for multi-line links.
  An N-by-8 numeric matrix with columns `x1, y1, x2, y2, x3, y3, x4, y4`
  in PDF user space (one row per line), or `NULL` for links that carry
  no `/QuadPoints` (single-rect links). Same shape as
  `pdf_annotations()$quad_points`.

Returns a 0-row tibble of the same schema when the page has no link
annotations.
