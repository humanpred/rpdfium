# Set the font color of an annotation

Wraps `FPDFAnnot_SetFontColor`. Routes through a transient form- fill
environment per PDFium's API.

## Usage

``` r
pdf_annot_set_font_color(annot, color)
```

## Arguments

- annot:

  A `pdfium_annot` (typically of subtype `"freetext"` or a widget —
  PDFium silently ignores the call on subtypes that don't carry a font).

- color:

  Numeric length-3 vector `c(R, G, B)` with values in `0:255`.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_font_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_font_color.md)
for the reader counterpart.
