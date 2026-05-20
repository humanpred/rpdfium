# Hit-test for a link annotation, returning its annotation index

Companion to
[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md)
(which surfaces the link's action / destination / URI) — this one
returns the page-scoped annotation index of the underlying link
annotation so the caller can hand it to
[`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_dict_value.md)
/
[`pdf_annot_appearance()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_appearance.md)
/
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
for the full structural readout. Wraps `FPDFLink_GetLinkAtPoint` +
`FPDFLink_GetAnnot`.

## Usage

``` r
pdf_link_annot_at_point(page, x, y, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- x, y:

  Point coordinates in PDF user-space points.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A list with three fields:

- `found` (logical) — `TRUE` when a link is under the point.

- `annotation_index` (integer) — 1-based same-page annotation index of
  the underlying link annotation; `NA` when no link is found.

- `z_order` (integer) — the link's Z-order on the page; `NA` when no
  link is found.

## See also

[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md),
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).
