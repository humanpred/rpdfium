# Remove an annotation and invalidate the handle

Wraps `FPDFPage_RemoveAnnot`. After the call, the annotation is gone
from the page's `/Annots` array, the underlying `FPDF_ANNOTATION` is
destroyed, and the R handle's externalptr is cleared so further
`pdf_annot_*` calls on it error cleanly via the package's `is_open()`
predicate.

## Usage

``` r
pdf_annot_delete(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Page-scoped indices on other annotation handles shift after a deletion;
re-fetch via
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
if you need fresh indices.

## See also

[`pdf_annot_new()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_new.md),
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md).
