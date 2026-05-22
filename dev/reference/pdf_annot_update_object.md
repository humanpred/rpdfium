# Update an embedded page-object after mutating it

Wraps `FPDFAnnot_UpdateObject`. Tells PDFium to re-serialise the
annotation's content stream after you've mutated one of the embedded
page-objects via the usual `pdf_*_set_*` setters.

## Usage

``` r
pdf_annot_update_object(annot, obj)
```

## Arguments

- annot:

  A `pdfium_annot`.

- obj:

  A `pdfium_obj` returned by
  [`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_objects.md).

## Value

Invisibly returns the parent `pdfium_doc`.
