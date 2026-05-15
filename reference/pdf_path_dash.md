# Dash pattern of a path page-object

Returns the dash array (in PDF points) and dash phase (offset into the
pattern, in points) attached to `obj`'s stroke. A solid (un-dashed) path
returns an empty `array` and phase `0`.

## Usage

``` r
pdf_path_dash(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)).

## Value

A named list with two elements:

- `array` - numeric vector of dash lengths in PDF points; length-zero
  for solid lines.

- `phase` - numeric scalar, the dash-pattern phase in points (typically
  `0`).

## Details

A dash array of `c(3, 2)` for example means: draw 3 points, skip 2
points, repeat. The phase shifts where in the pattern the first segment
starts.

## See also

[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_stroke.md)
for the stroke color and width.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  p <- pdf_load_page(doc, 1)
  path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
  pdf_path_dash(path_obj)
  pdf_close_page(p)
  pdf_close(doc)
}
```
