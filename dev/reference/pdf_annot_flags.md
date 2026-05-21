# Annotation flag bitmask

Returns the raw `/F` flag bitmask. Use
[`pdf_annot_flags_decoded()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_flags_decoded.md)
for the named-logical decomposition. Wraps `FPDFAnnot_GetFlags`.

## Usage

``` r
pdf_annot_flags(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md).

## Value

Integer scalar.
