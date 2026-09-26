# Extracting path geometry

Vector path geometry is the gap `pdfium` fills relative to other R PDF
libraries. `pdftools` and friends give you the rendered raster and the
text content but not the underlying path commands; this vignette walks
through the path API end-to-end.

``` r

library(pdfium)
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
```

## Per-page-object access

The lowest-level entry point is `pdf_path_segments(obj)` on a single
`"path"`-typed `pdfium_obj`. Each row is one path segment:

``` r

doc <- pdf_doc_open(fixture)
page <- pdf_page_load(doc, 1L)
paths <- Filter(function(o) o$type == "path", pdf_page_objects(page))
length(paths)
#> [1] 4

pdf_path_segments(paths[[1L]])
#> # A tibble: 5 × 9
#>   segment_index segment_type     x     y close_figure   cx1   cy1   cx2   cy2
#>           <int> <chr>        <dbl> <dbl> <lgl>        <dbl> <dbl> <dbl> <dbl>
#> 1             1 moveto           0     0 FALSE           NA    NA    NA    NA
#> 2             2 lineto         288     0 FALSE           NA    NA    NA    NA
#> 3             3 lineto         288   216 FALSE           NA    NA    NA    NA
#> 4             4 lineto           0   216 FALSE           NA    NA    NA    NA
#> 5             5 lineto           0     0 TRUE            NA    NA    NA    NA
```

Columns:

- `segment_index` — 1-based segment index within this path.
- `segment_type` — one of `"moveto"`, `"lineto"`, `"bezierto"`, or
  `"unknown"`.
- `x`, `y` — segment coordinates in PDF user space (points, origin
  bottom-left).
- `close_figure` — `TRUE` on the final segment of a closed sub-path.
- `cx1`, `cy1`, `cx2`, `cy2` — the two control points of the cubic
  Bezier curve that ends on this row; `NA` on every other row.

### Bezier curves

PDFium stores a cubic curve as three consecutive `"bezierto"` rows: the
first control point, the second control point, and the endpoint. The
endpoint row also carries the curve’s control points in
`cx1`/`cy1`/`cx2`/`cy2`, so keeping only the rows that have them gives
one row per curve (its start point is the previous row’s `x`/`y`):

``` r

canvas_doc <- pdf_doc_new()
canvas <- pdf_page_new(canvas_doc, 1, 200, 200)
curve <- pdf_path_new(canvas, 10, 10)
pdf_path_bezier_to(curve, 40, 90, 120, 90, 150, 10)
segs <- pdf_path_segments(curve)
segs
#> # A tibble: 4 × 9
#>   segment_index segment_type     x     y close_figure   cx1   cy1   cx2   cy2
#>           <int> <chr>        <dbl> <dbl> <lgl>        <dbl> <dbl> <dbl> <dbl>
#> 1             1 moveto          10    10 FALSE           NA    NA    NA    NA
#> 2             2 bezierto        40    90 FALSE           NA    NA    NA    NA
#> 3             3 bezierto       120    90 FALSE           NA    NA    NA    NA
#> 4             4 bezierto       150    10 FALSE           40    90   120    90
segs[!is.na(segs$cx1), c("x", "y", "cx1", "cy1", "cx2", "cy2")]
#> # A tibble: 1 × 6
#>       x     y   cx1   cy1   cx2   cy2
#>   <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#> 1   150    10    40    90   120    90
pdf_doc_close(canvas_doc)
```

[`pdf_path_append()`](https://humanpred.github.io/rpdfium/reference/pdf_path_append.md)
reads the triplet form back, so an edited
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
tibble can be replayed onto another path.

## Path style

Stroke and fill colour come back as 4-element numeric vectors
`(red, green, blue, alpha)` with values in 0..255. NA’s indicate “no
stroke” or “no fill” — paths can have either, both, or neither:

``` r

pdf_path_stroke(paths[[1L]])
#>   red green  blue alpha width 
#>     0     0     0   255     1
pdf_path_fill(paths[[1L]])
#>   red green  blue alpha 
#>   255   255   255   255
```

Dash pattern is a tibble with `pattern` (the on-off lengths) and `phase`
(the offset into the pattern):

``` r

pdf_path_dash(paths[[1L]])
#> $array
#> numeric(0)
#> 
#> $phase
#> [1] 0
```

The path’s transformation matrix (the CTM applied to its local
coordinates) comes from
[`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_matrix.md):

``` r

pdf_obj_matrix(paths[[1L]])
#>      [,1] [,2] [,3]
#> [1,]    1    0    0
#> [2,]    0   -1  216
#> [3,]    0    0    1
```

## One-call extraction

For consumers like `kmextract` that want one row per segment across a
page with style folded in,
[`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)
is the batched API:

``` r

all_paths <- pdf_extract_paths(fixture)
all_paths
#> # A tibble: 14 × 23
#>    path_index segment_index segment_type     x     y close_figure   cx1   cy1
#>         <int>         <int> <chr>        <dbl> <dbl> <lgl>        <dbl> <dbl>
#>  1          1             1 moveto          0    0   FALSE           NA    NA
#>  2          1             2 lineto        288    0   FALSE           NA    NA
#>  3          1             3 lineto        288  216   FALSE           NA    NA
#>  4          1             4 lineto          0  216   FALSE           NA    NA
#>  5          1             5 lineto          0    0   TRUE            NA    NA
#>  6          2             1 moveto         44   41.3 FALSE           NA    NA
#>  7          2             2 lineto        177.  41.3 FALSE           NA    NA
#>  8          2             3 lineto        177. 175.  FALSE           NA    NA
#>  9          2             4 lineto         44  175.  FALSE           NA    NA
#> 10          2             5 lineto         44   41.3 TRUE            NA    NA
#> 11          3             1 moveto        144  175.  FALSE           NA    NA
#> 12          3             2 lineto        244   41.3 FALSE           NA    NA
#> 13          4             1 moveto         44   41.3 FALSE           NA    NA
#> 14          4             2 lineto        244  175.  FALSE           NA    NA
#> # ℹ 15 more variables: cx2 <dbl>, cy2 <dbl>, stroke_red <dbl>,
#> #   stroke_green <dbl>, stroke_blue <dbl>, stroke_alpha <dbl>,
#> #   stroke_width <dbl>, fill_red <dbl>, fill_green <dbl>, fill_blue <dbl>,
#> #   fill_alpha <dbl>, bounds_left <dbl>, bounds_bottom <dbl>,
#> #   bounds_right <dbl>, bounds_top <dbl>
```

The result is a tibble. Schema:

- `path_index` — 1-based path-object index within the page (paths only;
  non-path objects don’t appear).
- `segment_index`, `segment_type`, `x`, `y`, `close_figure` — same
  content as
  [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md).
- `stroke_red/green/blue/alpha`, `fill_red/green/blue/alpha` — stroke
  and fill colours, 0..255. `NA` for paths with no stroke / no fill.
- `stroke_width` — stroke width in user space; `NA` for unstroked paths.
- `bounds_left/bottom/right/top` — path’s bounding box in PDF user
  space.

Three attributes carry per-page context:

``` r

attr(all_paths, "page_size")
#>  width height 
#>    288    216
attr(all_paths, "page_rotation")
#> [1] 0
nrow(attr(all_paths, "text_runs"))
#> [1] 1
```

- `page_size` — named numeric vector of `width` and `height` in PDF
  points.
- `page_rotation` — integer 0/90/180/270 (the page’s own `/Rotate`
  attribute).
- `text_runs` — a tibble of every text run on the page, shaped like the
  output of
  [`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md).
  Convenient when downstream consumers want to position labels relative
  to a curve.

## Filtering and inspecting paths in practice

A common workflow: select paths by stroke colour and inspect the segment
endpoints.

``` r

red_paths <- all_paths[
  !is.na(all_paths$stroke_red) &
    all_paths$stroke_red > 200 &
    all_paths$stroke_green < 50,
]
nrow(red_paths)
#> [1] 5
range(red_paths$x)
#> [1]  44.000 177.332
range(red_paths$y)
#> [1]  41.336 174.668
```

## Cleanup

``` r

pdf_page_close(page)
pdf_doc_close(doc)
```
