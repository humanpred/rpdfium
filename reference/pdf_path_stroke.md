# Stroke style of a path page-object

Returns the RGBA stroke color and stroke width of `obj` as a flat named
numeric vector. Color channels are integers in `[0, 255]`; width is in
PDF points. When PDFium reports that the object has no stroke set, every
value is `NA`.

## Usage

``` r
pdf_path_stroke(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)).

## Value

A named numeric vector with elements `red`, `green`, `blue`, `alpha`
(0-255 channels) and `width` (PDF points). All-`NA` when no stroke is
set.

## Details

The returned shape mirrors
[`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md)
(a flat named vector). The downstream tibble columns in
[`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)
(`stroke_red`, `stroke_green`, `stroke_blue`, `stroke_alpha`,
`stroke_width`) are built by prefixing the names of this vector.

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
