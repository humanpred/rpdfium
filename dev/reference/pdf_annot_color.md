# Annotation `/C` colour (RGBA, 0..1)

Returns the four colour channels as 0..1 doubles. `NA` if the annotation
has no `/C`.

## Usage

``` r
pdf_annot_color(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md).

## Value

Named numeric of length 4 (`red`, `green`, `blue`, `alpha`).

## See also

[`pdf_annot_interior_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_interior_color.md)
for `/IC`.
