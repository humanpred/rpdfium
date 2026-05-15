# Stroke style of a path page-object

Returns the RGBA stroke color and stroke width of `obj`. Color channels
are integers in `[0, 255]`; width is in PDF points. When PDFium reports
that the object has no stroke set, color channels are `NA` and width is
`NA`.

## Usage

``` r
pdf_path_stroke(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)).

## Value

A named list with two elements:

- `color` - a named numeric vector `c(red, green, blue, alpha)` of 0-255
  channel values, or all-`NA` when no stroke is set.

- `width` - the stroke width in PDF points, or `NA` when no stroke is
  set.

## See also

[`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md),
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  p <- pdf_load_page(doc, 1)
  path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
  pdf_path_stroke(path_obj)
  pdf_close_page(p)
  pdf_close(doc)
}
```
