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

- `index` - 1-based segment index within this path

- `type` - `"moveto"`, `"lineto"`, `"bezierto"`, or `"unknown"`

- `x`, `y` - the segment's anchor point in PDF points

- `close` - `TRUE` if this segment closes the current subpath (PDFium's
  `h` operator equivalent)

**Known limitation:** PDFium's segment readout API exposes only the
endpoint of a `bezierto` segment, not its two control points. Recovering
control points requires content-stream parsing and is deferred. For now,
`bezierto` rows show the curve's endpoint; the control-point information
is lost. See `dev/pdfium-api-review.md` for the full discussion.

## See also

[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md),
[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  p <- pdf_load_page(doc, 1)
  path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
  pdf_path_segments(path_obj)
  pdf_close_page(p)
  pdf_close(doc)
}
```
