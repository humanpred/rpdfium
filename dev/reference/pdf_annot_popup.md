# Annotation popup (`/Popup` linked annot)

Returns the popup annotation linked from this annotation's `/Popup`
entry as a fresh `pdfium_annot` handle, or `NULL` when the annotation
does not carry one. Wraps `FPDFAnnot_GetLinkedAnnot("Popup")`.

## Usage

``` r
pdf_annot_popup(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
  or
  [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_at.md).

## Value

A `pdfium_annot` handle or `NULL`.

## See also

[`pdf_annot_in_reply_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_in_reply_to.md).
