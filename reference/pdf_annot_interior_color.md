# Annotation `/IC` interior colour (RGBA, 0..1)

Returns the annotation's interior colour (used by line / square / circle
/ polygon subtypes). 0..1 doubles; `NA` if absent.

## Usage

``` r
pdf_annot_interior_color(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).

## Value

Named numeric of length 4.
