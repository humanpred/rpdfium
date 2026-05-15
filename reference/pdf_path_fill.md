# Fill color of a path page-object

Returns the RGBA fill color of `obj`. Channels are integers in
`[0, 255]`. When PDFium reports that the object has no fill set (e.g. a
stroke-only path), all four channels are `NA`.

## Usage

``` r
pdf_path_fill(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)).

## Value

A named numeric vector `c(red, green, blue, alpha)` of 0-255 channel
values, or all-`NA` when no fill is set.

## See also

[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_stroke.md),
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  p <- pdf_load_page(doc, 1)
  path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
  pdf_path_fill(path_obj)
  pdf_close_page(p)
  pdf_close(doc)
}
```
