# Remove all ink strokes from an ink annotation

Wraps `FPDFAnnot_RemoveInkList`. Clears the annotation's entire ink-list
array in one call.

## Usage

``` r
pdf_annot_remove_ink_list(annot)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"ink"`.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_add_ink_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_add_ink_stroke.md).
