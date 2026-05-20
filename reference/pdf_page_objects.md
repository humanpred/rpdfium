# Enumerate the objects on a page

Returns a list of `pdfium_obj` handles - one per drawing primitive on
the page, in PDFium's z-order (back to front). Each element carries its
type ("path", "text", "image", "form", "shading", "unknown"), a 1-based
index within the page, and an internal pointer suitable for passing to
downstream object queries.

## Usage

``` r
pdf_page_objects(page, page_num = 1L, recursive = FALSE)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc` (in which case the first page is loaded and closed
  automatically).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

- recursive:

  Logical. When `TRUE`, descend into every `"form"` page object via
  [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
  and return the flattened depth-first traversal: top-level objects
  first, then each form's nested objects immediately after the form,
  then any forms nested inside those, and so on. Nested objects carry
  the same `parent_form` slot that
  [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
  would set, so callers can reconstruct the tree from the flat list.
  Default `FALSE`.

## Value

A list (possibly empty) of `pdfium_obj` objects.

## Details

Page objects do not own their own lifetime - they remain valid only as
long as the parent `pdfium_page` is open. The handle's internal parent
reference keeps the page (and transitively the document) alive for as
long as you hold the object, but calling
[`pdf_page_close()`](https://humanpred.github.io/rpdfium/reference/pdf_page_close.md)
explicitly invalidates all returned objects.

## See also

[`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md),
[`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  p <- pdf_page_load(doc, 1)
  objs <- pdf_page_objects(p)
  length(objs)
  vapply(objs, pdf_obj_type, character(1))
  pdf_page_close(p)
  pdf_doc_close(doc)
}
```
