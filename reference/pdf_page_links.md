# List the clickable links on a page

Returns one tibble row per link annotation on the page, with the link's
bounding rectangle and the action it carries (target page for internal
links, URL for external links). Wraps `FPDFLink_Enumerate` plus the
per-link `FPDFLink_GetAnnotRect`, `FPDFLink_GetAction` / `_GetDest`,
`FPDFAction_GetType`, `FPDFAction_GetURIPath`, and
`FPDFDest_GetDestPageIndex`.

## Usage

``` r
pdf_page_links(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
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
  `"launch"` (launch an external file or application), `"unsupported"`.

- `uri` character - non-empty for `action_type == "uri"`; the target
  URL.

- `dest_page_num` integer - non-NA for `goto` / `remote_goto`; the
  1-based destination page within the current (or remote) document.

Returns a 0-row tibble of the same schema when the page has no link
annotations.
