# Appearance-stream string for an annotation

Returns the contents of an annotation's `/AP` appearance stream for the
requested appearance mode. PDF annotations can carry up to three
appearance streams: `"normal"` (default, drawn at rest), `"rollover"`
(drawn while the cursor hovers), and `"down"` (drawn while the
annotation is being activated). Wraps `FPDFAnnot_GetAP`.

## Usage

``` r
pdf_annot_appearance(
  page,
  annotation_index,
  mode = c("normal", "rollover", "down"),
  page_num = 1L
)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- annotation_index:

  One-based index into the page's annotations.

- mode:

  One of `"normal"` (default), `"rollover"`, or `"down"`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

Character scalar — the appearance-stream content, or `""` when no
appearance is set for the requested mode.

## Details

Useful for analysing or rebuilding custom annotations whose appearance
can't be reconstructed from the structural metadata
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
surfaces (color / border / quad points).

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md),
[`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_dict_value.md).
