# Annotation font colour (RGB, 0..1)

Returns the text-fill colour from the annotation's `/DA`. Three channels
in 0..1; `NA` when no colour is set.

## Usage

``` r
pdf_annot_font_color(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).

## Value

Named numeric of length 3 (`red`, `green`, `blue`).
