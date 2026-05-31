# Append a page-object to an annotation

Wraps `FPDFAnnot_AppendObject`. The page-object must be detached
(typically created by
[`pdf_path_new()`](https://humanpred.github.io/rpdfium/reference/pdf_path_new.md)
/
[`pdf_rect_new()`](https://humanpred.github.io/rpdfium/reference/pdf_rect_new.md)
/
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md)
/
[`pdf_image_new()`](https://humanpred.github.io/rpdfium/reference/pdf_image_new.md)
**before** it is inserted into a page). After the call, the annotation
owns the page-object — the R-side handle is cleared, so subsequent calls
on it error cleanly.

## Usage

``` r
pdf_annot_append_object(annot, obj)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"stamp"` or `"freetext"`.

- obj:

  A `pdfium_obj`.

## Value

Invisibly returns the parent `pdfium_doc`.
