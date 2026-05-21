# Annotation flags decoded as named logicals

Returns the six documented PDF annotation flag bits (Table 165 in the
PDF spec) as a named logical vector: `is_invisible`, `is_hidden`,
`is_print`, `is_no_view`, `is_read_only`, `is_locked`. Computed from
[`pdf_annot_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_flags.md).

## Usage

``` r
pdf_annot_flags_decoded(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md).

## Value

Named logical of length 6.
