# Link metadata for a link annotation

Wraps `FPDFAnnot_GetLink` plus the action/dest classification helpers.
Returns a single-row tibble with the same column shape as
[`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md)
(without the rect / quad_points geometry). `NULL` if `annot` has no link
entry.

## Usage

``` r
pdf_annot_link(annot)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"link"`.

## Value

A 1-row tibble with `action_type`, `uri`, `filepath`, `dest_page`,
`dest_view`, `dest_x`, `dest_y`, `dest_zoom`. `NULL` if the annotation
has no link entry.

## See also

[`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md)
for the page-wide enumeration.
