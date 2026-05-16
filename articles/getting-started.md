# Getting started with pdfium

`pdfium` exposes Google’s
[PDFium](https://pdfium.googlesource.com/pdfium/) engine to R. Where
`pdftools` (Poppler-based) gives you the text content and a rasterised
page, `pdfium` adds vector-level structure: every path object’s segments
and style, every text run’s font and bounding box, every embedded
image’s source bytes and metadata, every form XObject’s nested children,
and every clip region’s geometry. It complements rather than replaces
`pdftools` — the two cover different parts of the PDF inspection
surface.

This vignette walks through opening a document, inspecting its
structure, and pulling out a few common things. Three later vignettes go
deeper into
[paths](https://humanpred.github.io/rpdfium/articles/extracting-paths.md),
[text](https://humanpred.github.io/rpdfium/articles/text-extraction.md),
and
[rendering](https://humanpred.github.io/rpdfium/articles/rendering.md).

``` r

library(pdfium)
```

## Opening and closing a document

``` r

fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
doc <- pdf_open(fixture)
doc
#> <pdfium_doc [open] /home/runner/work/_temp/Library/pdfium/extdata/fixtures/shapes.pdf>
```

The returned object is an S3 handle wrapping a PDFium `FPDF_DOCUMENT`.
R’s garbage collector calls `FPDF_CloseDocument` when the handle becomes
unreachable, so you don’t *have* to close it explicitly — but for large
documents or when you need to delete the source file afterward (Windows
blocks deletion of open files), close it yourself with
[`pdf_close()`](https://humanpred.github.io/rpdfium/reference/pdf_close.md):

``` r

pdf_count <- pdf_page_count(doc)
pdf_count
#> [1] 1
```

Both
[`pdf_page_count()`](https://humanpred.github.io/rpdfium/reference/pdf_page_count.md)
and
[`pdf_doc_info()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_info.md)
also accept a path directly when you want a one-shot inspection. The
package opens and closes the document for you in that case:

``` r

pdf_page_count(fixture)
#> [1] 1
```

## Document metadata

[`pdf_doc_info()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_info.md)
returns the page count, file version, every standard Info-dictionary
entry, and POSIXct parses of the two date fields. The shape mirrors
`pdftools::pdf_info()` for easy porting:

``` r

info <- pdf_doc_info(doc)
info$page_count
#> [1] 1
info$file_version       # PDFium reports 10 * major + minor (17 = PDF 1.7)
#> [1] 17
info$producer
#> [1] "cairo 1.18.0 (https://cairographics.org)"
info$creation_date_parsed
#> [1] "2026-05-15 19:12:28 UTC"
```

For a single tag use `pdf_doc_meta(doc, "Producer")`. The standard tags
PDFium recognises are `"Title"`, `"Author"`, `"Subject"`, `"Keywords"`,
`"Creator"`, `"Producer"`, `"CreationDate"`, `"ModDate"`, and
`"Trapped"`. Missing tags return the empty string.

If you have a date string in PDF format (`"D:YYYYMMDDHHmmSS+HH'mm'"`),
[`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
parses it into UTC POSIXct. It’s vectorised and accepts truncated forms:

``` r

pdf_parse_date(c("D:20240115123045Z", "D:2024"))
#> [1] "2024-01-15 12:30:45 UTC" "2024-01-01 00:00:00 UTC"
```

## Pages and page objects

A page is loaded with `pdf_load_page(doc, page_num)`. The returned
handle carries a reference to its parent doc so GC ordering is safe:

``` r

page <- pdf_load_page(doc, 1L)
pdf_page_size(doc, 1L)        # width and height in PDF points
#>  width height 
#>    288    216
pdf_page_rotation(doc, 1L)    # 0, 90, 180, or 270 degrees
#> [1] 0
```

Every drawable element on a page is a *page object*.
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
returns them as a list of typed `pdfium_obj` handles:

``` r

objs <- pdf_page_objects(page)
length(objs)
#> [1] 5
vapply(objs, function(o) o$type, character(1))
#> [1] "path" "path" "path" "path" "text"
```

Each object’s type is one of `"path"` (vector path with line/curve
segments), `"text"` (a text run), `"image"` (embedded raster), `"form"`
(a Form XObject - a reusable sub-page; see the section below), or
`"shading"` (a smooth-shading object).

You can read each object’s bounding box on the page in PDF user space
(points, origin at the page’s bottom-left):

``` r

pdf_obj_bounds(objs[[1L]])
#>   left bottom  right    top 
#>      0      0    288    216
```

And its transformation matrix (the CTM applied when the object is
drawn):

``` r

pdf_obj_matrix(objs[[1L]])
#>      [,1] [,2] [,3]
#> [1,]    1    0    0
#> [2,]    0   -1  216
#> [3,]    0    0    1
```

The accessors that work on every page object are
[`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md),
[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md),
[`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_matrix.md).
Type-specific accessors follow naming conventions: `pdf_path_*`,
`pdf_text_*`, `pdf_image_*`.

## Path geometry

For path objects,
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
returns a tibble of segment coordinates plus a `close_figure` flag on
each segment:

``` r

paths <- Filter(function(o) o$type == "path", objs)
pdf_path_segments(paths[[1L]])
#> # A tibble: 5 × 5
#>   segment_index segment_type     x     y close_figure
#>           <int> <chr>        <dbl> <dbl> <lgl>       
#> 1             1 moveto           0     0 FALSE       
#> 2             2 lineto         288     0 FALSE       
#> 3             3 lineto         288   216 FALSE       
#> 4             4 lineto           0   216 FALSE       
#> 5             5 lineto           0     0 TRUE
```

Stroke and fill colour, dash pattern, and miscellaneous style come back
as separate accessors:

``` r

pdf_path_stroke(paths[[1L]])
#>   red green  blue alpha width 
#>     0     0     0   255     1
pdf_path_fill(paths[[1L]])
#>   red green  blue alpha 
#>   255   255   255   255
pdf_path_dash(paths[[1L]])
#> $array
#> numeric(0)
#> 
#> $phase
#> [1] 0
```

For a one-call extraction that returns one row per segment across every
path on every page — the shape `kmextract` and similar consumers expect
— use `pdf_extract_paths(path_or_doc)`:

``` r

extracted <- pdf_extract_paths(fixture)
str(extracted, max.level = 1L)
#> tibble [14 × 19] (S3: tbl_df/tbl/data.frame)
#>  - attr(*, "page_size")= Named num [1:2] 288 216
#>   ..- attr(*, "names")= chr [1:2] "width" "height"
#>  - attr(*, "page_rotation")= int 0
#>  - attr(*, "text_runs")= tibble [1 × 13] (S3: tbl_df/tbl/data.frame)
nrow(extracted)
#> [1] 14
head(extracted, 3L)
#> # A tibble: 3 × 19
#>   path_index segment_index segment_type     x     y close_figure stroke_red
#>        <int>         <int> <chr>        <dbl> <dbl> <lgl>             <dbl>
#> 1          1             1 moveto           0     0 FALSE                 0
#> 2          1             2 lineto         288     0 FALSE                 0
#> 3          1             3 lineto         288   216 FALSE                 0
#> # ℹ 12 more variables: stroke_green <dbl>, stroke_blue <dbl>,
#> #   stroke_alpha <dbl>, stroke_width <dbl>, fill_red <dbl>, fill_green <dbl>,
#> #   fill_blue <dbl>, fill_alpha <dbl>, bounds_left <dbl>, bounds_bottom <dbl>,
#> #   bounds_right <dbl>, bounds_top <dbl>
```

The result is a tibble with one row per path segment, plus per-path
attributes (stroke/fill color, page size, etc.) and a `text_runs`
attribute carrying the page’s text in tabular form. See the
[extracting-paths](https://humanpred.github.io/rpdfium/articles/extracting-paths.md)
vignette for the full schema.

## Text content

`pdf_text_content(text_obj)` returns the Unicode string for one text
object, and `pdf_text_runs(page)` enumerates every text run on a page
with positions, font sizes, and font metadata:

``` r

runs <- pdf_text_runs(page)
runs
#> # A tibble: 1 × 13
#>   text_index bounds_left bounds_bottom bounds_right bounds_top font_size text 
#>        <int>       <dbl>         <dbl>        <dbl>      <dbl>     <dbl> <chr>
#> 1          5        129.          103.         159.       114.         1 Hello
#> # ℹ 6 more variables: font_base_name <chr>, font_family <chr>,
#> #   font_weight <int>, font_italic_angle <int>, font_is_embedded <lgl>,
#> #   font_flags <int>
```

For one-text-object access (font name, weight, embedded flag) use
`pdf_text_font(text_obj)`. See the
[text-extraction](https://humanpred.github.io/rpdfium/articles/text-extraction.md)
vignette for the full set.

## Rendering

To rasterise a page, `pdf_render_page(page_or_doc, dpi)` returns a
`pdfium_bitmap` object that inherits from base R’s `nativeRaster`:

``` r

bmp <- pdf_render_page(doc, dpi = 96)
bmp
#> <pdfium_bitmap 384x288 @ 96 dpi, page 1 of shapes.pdf>
dim(bmp)        # height, width
#> [1] 288 384
```

`pdfium_bitmap` is directly usable by
[`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html),
[`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html),
and [`grid::rasterGrob()`](https://rdrr.io/r/grid/grid.raster.html).
Three converters produce other common shapes:

``` r

arr <- as.array(bmp)        # 3D [H, W, 4] doubles in 0..1, like png::writePNG
ras <- as.raster(bmp)       # base R "raster" class, hex-color matrix
mat <- as.matrix(bmp)       # plain character matrix
```

The save helper `pdf_render_to_png(file, ...)` writes the bitmap
straight to a PNG file via the `png` package (a Suggests dependency).

## Embedded images and form XObjects

For object-type-specific extraction, see:

- [`pdf_image_info()`](https://humanpred.github.io/rpdfium/reference/pdf_image_info.md)
  /
  [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
  /
  [`pdf_image_data()`](https://humanpred.github.io/rpdfium/reference/pdf_image_data.md)
  for embedded raster images. The raw-stream-bytes path
  (`pdf_image_data(decoded = FALSE)`) lets you save the original
  JPEG/JBIG2/JPEG2000 without re-encoding.
- [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
  to walk the page objects nested inside a Form XObject (a reusable
  sub-page used for tiling patterns, glyph procedures, annotation
  appearance streams, etc.).
- [`pdf_obj_clip_path()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_clip_path.md)
  /
  [`pdf_clip_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_segments.md)
  to read the clip geometry attached to a page object.

## Cleanup

``` r

pdf_close_page(page)
pdf_close(doc)
```

[`pdf_close()`](https://humanpred.github.io/rpdfium/reference/pdf_close.md)
and
[`pdf_close_page()`](https://humanpred.github.io/rpdfium/reference/pdf_close_page.md)
are idempotent — calling them more than once is a no-op. R’s GC also
runs the finalisers automatically when handles become unreachable. The
[architecture](https://humanpred.github.io/rpdfium/articles/architecture.md)
vignette covers the memory model in depth.
