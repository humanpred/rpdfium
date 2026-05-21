# Annotation font size (FreeText / Widget subtypes)

Returns the text-fill font size from the annotation's `/DA` (default
appearance string). Meaningful for FreeText / Widget subtypes; `NA` for
others.

## Usage

``` r
pdf_annot_font_size(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md).

## Value

Numeric scalar; `NA` when the subtype doesn't carry text.
