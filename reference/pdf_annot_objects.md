# Page-objects embedded inside an annotation

Wraps `FPDFAnnot_GetObject` over the full count and
`FPDFPageObj_GetType` for each object. PDFium parses the objects from
the annotation's normal (`/AP /N`) appearance stream. Returns a list of
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

A list of `pdfium_obj` handles in appearance-stream order (zero-length
when the annotation has no embedded objects).

## Details

Each handle's `type` is the object's own type (`"path"`, `"text"`,
`"image"`, `"shading"` or `"form"`), as in
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
and
[`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md),
so the type-specific readers and setters take it:
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
or
[`pdf_path_set_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_fill.md)
on a path,
[`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_set_content.md)
on text,
[`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
on a form, and so on.
[`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md)
is the exception: PDFium reads text through the page's text layer, which
has no annotation content, so it refuses these objects.

A setter changes the object in memory only. Call
[`pdf_annot_update_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_update_object.md)
afterwards to rewrite the appearance stream from the annotation's
objects;
[`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md)
writes that stream, so a change left out of it is not saved. The rewrite
drops shading objects and inline images, which PDFium's content writer
does not serialise.

## See also

[`pdf_annot_object_count()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_object_count.md),
[`pdf_annot_append_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_append_object.md),
[`pdf_annot_update_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_update_object.md).
