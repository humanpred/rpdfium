# List the page objects nested inside a Form XObject

Wraps `FPDFFormObj_CountObjects` + `FPDFFormObj_GetObject` to enumerate
the page objects contained in a Form XObject. The returned objects
participate in the regular `pdfium_obj` API - you can call
[`pdf_obj_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_type.md),
[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_bounds.md),
[`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_matrix.md),
and (per object type)
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md)
/
[`pdf_image_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_info.md)
/
[`pdf_text_content()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_content.md)
on each one. Nesting is recursive: a Form XObject may itself contain
other Form XObjects, and the returned `pdfium_obj`s of type `"form"` can
be passed back into `pdf_form_objects()`.

## Usage

``` r
pdf_form_objects(form)
```

## Arguments

- form:

  A `pdfium_obj` of type `"form"`, typically obtained by filtering
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
  (or another `pdf_form_objects()` call) on `type == "form"`.

## Value

A list of `pdfium_obj`s, one per nested page object. Empty list when the
form has no children.

## Details

Each returned object carries a `parent_form` slot pointing back at
`form`, used by the print/format methods to show the containment path
(`"obj 2 of form 1 on page 1"`). Lifetime is bound to the parent page,
not to the form: as long as the page is open, the form and its nested
objects remain valid.

## See also

[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
for the top-level enumeration,
[`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_matrix.md)
for the form's own transformation matrix.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "form_xobject.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  page <- pdf_page_load(doc, 1L)
  forms <- Filter(function(o) o$type == "form", pdf_page_objects(page))
  if (length(forms) > 0L) {
    nested <- pdf_form_objects(forms[[1L]])
    length(nested)
  }
  pdf_page_close(page)
  pdf_doc_close(doc)
}
```
