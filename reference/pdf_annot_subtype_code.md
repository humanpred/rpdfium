# Annotation subtype code (integer enum)

Returns the raw `FPDF_ANNOT_*` integer for the annotation. Useful when
round-tripping into writers that take the enum directly.

## Usage

``` r
pdf_annot_subtype_code(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).

## Value

Integer in `0..28`.
