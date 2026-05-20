# Annotation border width

Returns the stroke border width from `/Border` or `/BS`.

## Usage

``` r
pdf_annot_border_width(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).

## Value

Numeric scalar; `NA` if no border.
