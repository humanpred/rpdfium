# Extract all path geometry on a page into a single tibble

One-call helper that opens a document (or accepts an already-open one),
enumerates every path object on the requested page, and returns a tibble
with one row per path segment carrying both the geometry and the
containing path's stroke / fill style and bounding box. This is the
function `kmextract` consumes via the `pdfium_native` backend.

## Usage

``` r
pdf_extract_paths(doc, page_num = 1L)
```

## Arguments

- doc:

  Either a character scalar path to a PDF file, or an already-open
  `pdfium_doc` returned by
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md).
  When `doc` is a character path the document is opened and closed
  internally.

- page_num:

  One-based page index (default `1`).

## Value

A tibble with the schema described above.

## Details

### Returned tibble

Each row describes one path-segment operator (a `moveto`, `lineto`, or
`bezierto`), in the order PDFium emits them:

Path identity & segment geometry:

- `path_index` - 1-based index of the parent path object on the page

- `segment_index` - 1-based segment index within the path

- `segment_type` - `"moveto"`, `"lineto"`, `"bezierto"`, or `"unknown"`

- `x`, `y` - the segment's anchor / endpoint in PDF points

- `close_figure` - logical, segment closes the current subpath

Style (constant across all rows of one path):

- `stroke_red`, `stroke_green`, `stroke_blue`, `stroke_alpha` - 0-255
  channels; `NA` if no stroke

- `stroke_width` - PDF points; `NA` if no stroke

- `fill_red`, `fill_green`, `fill_blue`, `fill_alpha` - 0-255 channels;
  `NA` if no fill

Path bounding box (constant across rows of one path):

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` - PDF
  points

### Attributes

- `page_size` - named numeric `c(width, height)` of the page in PDF
  points, from
  [`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)

- `page_rotation` - integer in `{0, 90, 180, 270}`, from
  [`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)

- `text_runs` - tibble with one row per text object on the page, the
  output of
  [`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md).

### Known limitations

- Bezier control points are not exposed - only segment endpoints. PDFium
  does not expose them through its public C API; see
  `dev/decisions/ADR-009-defer-bezier-controls.md`.

## See also

[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md),
[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_stroke.md),
[`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md),
[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  paths <- pdf_extract_paths(fixture, page_num = 1)
  head(paths)
  attr(paths, "page_size")
  attr(paths, "text_runs")
}
#> # A tibble: 1 × 13
#>   text_index bounds_left bounds_bottom bounds_right bounds_top font_size text 
#>        <int>       <dbl>         <dbl>        <dbl>      <dbl>     <dbl> <chr>
#> 1          5        129.          103.         159.       114.         1 Hello
#> # ℹ 6 more variables: font_base_name <chr>, font_family <chr>,
#> #   font_weight <int>, font_italic_angle <int>, font_is_embedded <lgl>,
#> #   font_flags <int>
```
