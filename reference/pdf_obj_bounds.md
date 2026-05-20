# Axis-aligned bounding box of a page object

Returns the smallest rectangle, in PDF point coordinates, that contains
all visible parts of `obj`. The bounds are in the page's own coordinate
system, i.e. origin at the bottom-left of the un-rotated media box
(matching
[`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)).
Note that the bounds are not adjusted for the page's rotation; consult
[`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)
when comparing positions across rotated pages.

## Usage

``` r
pdf_obj_bounds(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md).

## Value

A named numeric vector with elements `left`, `bottom`, `right`, `top`.
Width is `right - left`, height is `top - bottom`.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  p <- pdf_page_load(doc, 1)
  objs <- pdf_page_objects(p)
  pdf_obj_bounds(objs[[1]])
  pdf_page_close(p)
  pdf_doc_close(doc)
}
```
