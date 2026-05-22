# Number of embedded page-objects inside an annotation

Wraps `FPDFAnnot_GetObjectCount`. Stamp and FreeText annotations carry
their visual content as a small page-object tree;
`pdf_annot_object_count()` reports how many top-level objects are
inside.

## Usage

``` r
pdf_annot_object_count(annot)
```

## Arguments

- annot:

  A `pdfium_annot`.

## Value

Integer scalar (zero or positive).

## See also

[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_objects.md),
[`pdf_annot_append_object()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_append_object.md).
