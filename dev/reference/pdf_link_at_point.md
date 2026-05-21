# Hit-test for the link annotation under a point

Finds the link annotation at PDF user-space coordinates `(x, y)` on a
page. Useful for translating a click on a rendered PDF back to its
semantic target. Wraps `FPDFLink_GetLinkAtPoint` plus the
`FPDFLink_GetLinkZOrderAtPoint` / `FPDFLink_GetAction` / `FPDFAction_*`
family.

## Usage

``` r
pdf_link_at_point(page, x, y, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- x, y:

  Point coordinates in PDF user-space points.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with at most one row. Columns:

- `z_order` — integer, the link's Z-order on the page (higher = on top).

- `left`, `bottom`, `right`, `top` — link's rectangle in PDF points.

- `action_type` — character: `"goto"`, `"remote_goto"`, `"uri"`,
  `"launch"`, `"embedded_goto"`, or `"unsupported"`.

- `uri` — the link target URI when `action_type == "uri"`, `NA`
  otherwise.

- `filepath` — the external file path when `action_type` is
  `"remote_goto"` / `"launch"` / `"embedded_goto"`, `NA` otherwise.

- `dest_page` — the resolved 1-based target page for any GoTo action
  (`NA` if not resolvable).

Empty tibble (0 rows) when no link sits under the point.

## Details

Coordinates are in PDF user-space points (origin at the page's
bottom-left; page width and height in points come from
[`pdf_page_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_size.md)).

## See also

[`pdf_page_links()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_links.md)
for the full enumeration.
