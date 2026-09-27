# Remove a page-object from an annotation

Wraps `FPDFAnnot_RemoveObject`. The object is identified by its position
within the annotation's embedded content (one-based, matching
[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md)).
PDFium destroys the object and regenerates the annotation's appearance
stream. The handles to the object from earlier
[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md)
calls on `annot` are closed, and so are the clip paths and nested
objects read from them: further calls on them error cleanly. The handles
to the remaining objects stay valid, but their positions shift down by
one; call
[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md)
again for the new positions. Objects read through another handle to the
same annotation, for example from a second
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
call, are separate copies and are not affected.

## Usage

``` r
pdf_annot_remove_object(annot, index)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"ink"` or `"stamp"`, the only subtypes
  PDFium edits embedded objects of. Parent doc must be readwrite.

- index:

  One-based index of the embedded object to remove.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_append_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_append_object.md),
[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md).
