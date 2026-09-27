# Move a page-object into an annotation

Wraps `FPDFAnnot_AppendObject`. The page-object becomes part of the
annotation's appearance stream, which PDFium regenerates straight away.

## Usage

``` r
pdf_annot_append_object(annot, obj)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"ink"` or `"stamp"`, the only subtypes
  PDFium lets hold page-objects (`FPDFAnnot_IsObjectSupportedSubtype`).
  Parent doc must be readwrite.

- obj:

  A `pdfium_obj` that is a top-level object of the page handle `annot`
  belongs to, e.g. from
  [`pdf_rect_new()`](https://humanpred.github.io/rpdfium/reference/pdf_rect_new.md)
  or
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
  on that page. Objects nested in a form XObject
  ([`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)),
  objects already inside an annotation
  ([`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md))
  and objects on another page are rejected.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

PDFium takes ownership of the object it is given and expects it to be
free-standing, but every page-object creator in this package
([`pdf_path_new()`](https://humanpred.github.io/rpdfium/reference/pdf_path_new.md),
[`pdf_rect_new()`](https://humanpred.github.io/rpdfium/reference/pdf_rect_new.md),
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md),
[`pdf_image_new()`](https://humanpred.github.io/rpdfium/reference/pdf_image_new.md),
...) inserts its object into a page. This function therefore *moves* the
object: it takes `obj` off the annotation's page
(`FPDFPage_RemoveObject`) and then appends it to `annot`, so exactly one
of them owns the object at any time.

After the call `obj` is no longer on the page and its handle is closed;
reach the object through
[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md)
instead. Other handles to the same object (for example from an earlier
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
call) are stale and must not be used, and the page-scoped indices of the
remaining page-objects shift down by one. The move only succeeds as a
whole: when `annot` cannot hold page-objects, or `obj` is not a
top-level object of the annotation's page, nothing changes and the
function errors.

## See also

[`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md),
[`pdf_annot_update_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_update_object.md),
[`pdf_annot_remove_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_remove_object.md).
