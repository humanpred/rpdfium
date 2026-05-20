# Page additional actions (open / close handlers)

PDF pages can declare actions that fire when the page is opened
(`/AA/O`) or closed (`/AA/C`) — for example, to play a sound, run
JavaScript, or follow a URI. `pdf_page_actions()` enumerates those
actions for one page. Wraps `FPDF_GetPageAAction` plus the
`FPDFAction_*` accessors.

## Usage

``` r
pdf_page_actions(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with one row per defined additional-action. Columns:

- `trigger` — `"open"` or `"close"`.

- `action_type` — same vocabulary as
  [`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md)'s
  `action_type`.

- `uri`, `filepath`, `dest_page` — payload columns, same shape as in
  [`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md).

## Details

Most PDFs don't declare page additional-actions; the typical result is
an empty tibble.
