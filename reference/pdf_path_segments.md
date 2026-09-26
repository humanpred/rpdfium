# Path segments of a path page-object

Returns one row per segment of the path. Segments are emitted in the
same order they appear in the page's content stream, which is the same
order PDFium's rendering pipeline consumes. The result is suitable for
plotting the geometry or for downstream coordinate analysis.

## Usage

``` r
pdf_path_segments(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)).

## Value

A tibble with the columns described above. An empty path returns a 0-row
tibble of the same shape.

## Details

Each row carries:

- `segment_index` - 1-based segment index within this path

- `segment_type` - `"moveto"`, `"lineto"`, `"bezierto"`, or `"unknown"`

- `x`, `y` - the segment's point in PDF points

- `close_figure` - `TRUE` if this segment closes the current subpath
  (PDFium's `h` operator equivalent)

- `cx1`, `cy1`, `cx2`, `cy2` - the two control points of the cubic
  Bezier curve that ends at this row; `NA` on every other row

### Bezier curves

PDFium stores a cubic Bezier curve (the `c`, `v`, and `y` content
operators) as three consecutive `"bezierto"` rows: the first control
point, the second control point, and the curve's endpoint, in that
order. The endpoint row additionally carries the curve's control points
in `cx1`/`cy1`/`cx2`/`cy2` (wraps `FPDFPath_GetBezierControlPoints`), so
`subset(segs, !is.na(cx1))` gives one row per curve, with the curve's
start point being the previous row's `x`/`y`. The control-point rows
keep `cx1`..`cy2` as `NA`, which is how to tell them apart from
endpoints.
[`pdf_path_append()`](https://humanpred.github.io/rpdfium/reference/pdf_path_append.md)
consumes the triplet form, so the output round-trips.

## See also

[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md),
[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  p <- pdf_page_load(doc, 1)
  path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
  pdf_path_segments(path_obj)
  pdf_page_close(p)
  pdf_doc_close(doc)
}
```
