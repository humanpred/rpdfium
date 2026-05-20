# Hit-test for a link annotation, returning the annotation handle

Companion to
[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md)
(which surfaces the link's action / destination / URI) — this one
returns the underlying link `pdfium_annot` handle (or `NULL` when
nothing's there) so the caller can hand it to per-annotation getters
([`pdf_annot_subtype()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_subtype.md),
[`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_dict_value.md),
[`pdf_annot_appearance()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_appearance.md),
...) or splice it back into
[`as_pdfium_annot_list()`](https://humanpred.github.io/rpdfium/reference/as_pdfium_annot_list.md).
Wraps `FPDFLink_GetLinkAtPoint` + `FPDFLink_GetAnnot`, then re-loads the
annotation through
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)'s
shared shim so the handle owns its own lifetime.

## Usage

``` r
pdf_link_annot_at_point(page, x, y, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- x, y:

  Point coordinates in PDF user-space points.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A `pdfium_annot` handle, or `NULL` when no link annotation is under the
point.

## See also

[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md),
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).
