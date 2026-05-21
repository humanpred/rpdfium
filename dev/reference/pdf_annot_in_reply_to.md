# Annotation reply-to (`/IRT` linked annot)

Returns the annotation this one replies to (its `/IRT` "in reply to"
target) as a `pdfium_annot` handle, or `NULL` when this annotation is
not a reply. Wraps `FPDFAnnot_GetLinkedAnnot("IRT")`.

## Usage

``` r
pdf_annot_in_reply_to(annot)
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

[`pdf_annot_popup()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_popup.md).
