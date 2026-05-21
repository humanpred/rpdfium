# Create a new annotation on a page

Wraps `FPDFPage_CreateAnnot` + (optionally) `FPDFAnnot_SetRect`. PDFium
supports creating annotations of subtype `"circle"`, `"fileattachment"`,
`"freetext"`, `"highlight"`, `"ink"`, `"link"`, `"popup"`, `"square"`,
`"squiggly"`, `"stamp"`, `"strikeout"`, `"text"`, and `"underline"`.
Other subtypes (`"widget"`, `"polygon"`, `"line"`, etc.) error from
PDFium.

## Usage

``` r
pdf_annot_new(page, subtype, bounds = NULL)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md).
  Parent doc must be readwrite.

- subtype:

  Character scalar — one of the supported annotation subtypes listed
  above.

- bounds:

  Optional length-4 numeric vector `c(left, bottom, right, top)` in PDF
  user-space points. Default `NULL` (annotation has no rect set — most
  subtypes still need one and you'll likely follow up with
  [`pdf_annot_set_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_bounds.md)).

## Value

The new `pdfium_annot` handle.

## Details

The new annotation is appended to the page's `/Annots` array. Use
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
to re-read the page if you need an updated handle list — the new
annotation lands at the end.

## See also

[`pdf_annot_delete()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_delete.md),
[`pdf_annot_set_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_bounds.md),
[`pdf_annot_set_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_color.md),
[`pdf_annot_set_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_contents.md).
