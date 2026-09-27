# Remove an annotation and invalidate the handle

Wraps `FPDFPage_GetAnnotIndex`, `FPDFPage_RemoveAnnot` and
`FPDFPage_CloseAnnot`. The handle's annotation is located on the page
when the call is made, so it is the one removed even after other
annotations on the page were deleted. The annotation leaves the page's
`/Annots` array, PDFium's annotation context is released together with
any page-objects of its appearance stream, and the handle is closed:
further `pdf_annot_*` calls on it, and on page-objects read from it with
[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md),
error cleanly.

## Usage

``` r
pdf_annot_delete(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

## Value

Invisibly returns the parent `pdfium_doc`. Errors, changing nothing,
when the annotation is no longer on its page, for example because it was
deleted through another handle.

## Details

Later annotations on the page move down one position. Other handles
still print the position they had when they were made;
[`pdf_annot_index()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_index.md)
gives the current one.

## See also

[`pdf_annot_new()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_new.md),
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md),
[`pdf_annot_index()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_index.md).
