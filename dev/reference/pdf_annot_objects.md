# Page-objects embedded inside an annotation

Wraps `FPDFAnnot_GetObject` over the full count. Returns a list of
`pdfium_obj` handles; each handle's externalptr pins the parent
annotation, so the embedded objects can't dangle past the annot's
lifetime.

## Usage

``` r
pdf_annot_objects(annot)
```

## Arguments

- annot:

  A `pdfium_annot`.

## Value

A list of `pdfium_obj` handles (zero-length when the annotation has no
embedded objects).

## See also

[`pdf_annot_object_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_object_count.md),
[`pdf_annot_append_object()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_append_object.md).
