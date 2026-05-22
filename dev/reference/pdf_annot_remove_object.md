# Remove a page-object from an annotation

Wraps `FPDFAnnot_RemoveObject`. The object is identified by its position
within the annotation's embedded content (one-based, matching
[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_objects.md)).

## Usage

``` r
pdf_annot_remove_object(annot, index)
```

## Arguments

- annot:

  A `pdfium_annot`.

- index:

  One-based index of the embedded object to remove.

## Value

Invisibly returns the parent `pdfium_doc`.
