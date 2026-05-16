# Extracting text and fonts

`pdfium` exposes text at the level of *text runs* — the contiguous runs
of glyphs that share a font, size, and rendering state. Each run carries
its bounding box, the Unicode content, and font metadata. Where
`pdftools::pdf_text()` returns plain strings, `pdfium` lets you connect
each character to where it sits on the page and what font drew it.

``` r

library(pdfium)
fixture <- system.file("extdata", "fixtures", "unicode.pdf",
                       package = "pdfium")
doc <- pdf_open(fixture)
page <- pdf_load_page(doc, 1L)
```

## Whole-page extraction

`pdf_text_runs(page)` returns one row per text-typed page object on the
page, with content + position + font in a single tibble:

``` r

runs <- pdf_text_runs(page)
runs
#> # A tibble: 5 × 13
#>   text_index bounds_left bounds_bottom bounds_right bounds_top font_size text 
#>        <int>       <dbl>         <dbl>        <dbl>      <dbl>     <dbl> <chr>
#> 1          2        130.          171.         158.       180.         1 Hello
#> 2          3        129.          137.         158.       146.         1 world
#> 3          4        126.          103.         138.       114.         1 pd   
#> 4          5        140.          105.         145.       114.         1 fi   
#> 5          6        146.          105.         162.       112.         1 um   
#> # ℹ 6 more variables: font_base_name <chr>, font_family <chr>,
#> #   font_weight <int>, font_italic_angle <int>, font_is_embedded <lgl>,
#> #   font_flags <int>
```

Columns (use `names(runs)` for the canonical list — the names below
match the schema PDFium reports today):

- `object_index` — 1-based page-object index. Matches the index in
  `pdf_page_objects(page)`.
- `bbox_left`, `bbox_bottom`, `bbox_right`, `bbox_top` — bounding box in
  PDF user space (points, origin bottom-left).
- `font_size_pt` — the font size as PDFium reports it (in user-space
  points, before the text matrix is applied).
- `text` — Unicode content of the run, UTF-8 encoded.
- `font_base_name` — `BaseFont` from the font dictionary.
- `font_family` — `FontFamily` if present.
- `font_weight` — integer 100..900 (CSS-style; 400 ≈ regular, 700 ≈
  bold).
- `font_italic_angle` — italic angle in degrees, 0 for upright fonts.
- `font_is_embedded` — logical; `TRUE` if the font program is embedded.
- `font_flags` — PDF font-descriptor `/Flags` bitmask (fixed-pitch,
  serif, symbolic, …).

## Per-object access

When you already have a specific text-typed `pdfium_obj` in hand —
typically from filtering
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
— three accessors give you the same data piecewise:

``` r

texts <- Filter(function(o) o$type == "text", pdf_page_objects(page))
length(texts)
#> [1] 5

pdf_text_content(texts[[1L]])       # the Unicode string
#> [1] "Hello"
pdf_text_font_size(texts[[1L]])     # font size in user-space points
#> [1] 1
str(pdf_text_font(texts[[1L]]))     # named list of font metadata
#> List of 6
#>  $ font_base_name   : chr "NimbusSans-Regular"
#>  $ font_family      : chr "Nimbus Sans"
#>  $ font_weight      : int 400
#>  $ font_italic_angle: int 0
#>  $ font_is_embedded : logi TRUE
#>  $ font_flags       : int 4
```

[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
is essentially a batched form of these three accessors joined with
[`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md),
returned as a single tibble.

## Unicode and font notes

UTF-16LE comes through correctly for every script PDFium knows how to
decode — including CJK ideographs, Latin diacritics, and characters
outside the Basic Multilingual Plane that need surrogate pairs:

``` r

Encoding(pdf_text_content(texts[[1L]]))
#> [1] "unknown"
nchar(pdf_text_content(texts[[1L]]))
#> [1] 5
```

A few caveats worth knowing about:

- **Glyph IDs vs Unicode.** If a PDF uses a non-standard font without a
  `/ToUnicode` CMap, PDFium can’t always map glyph IDs back to Unicode.
  In those cases
  [`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md)
  returns the best-effort decoding; some characters may come through as
  private-use codepoints or as `?`. This is a property of the source
  PDF, not of `pdfium`.
- **Text matrix.** `font_size_pt` is the font size that PDFium reports.
  The effective glyph height on the page is
  `font_size_pt * abs(matrix$d)` where `matrix` comes from
  `pdf_obj_matrix(text_obj)`.

## Combining text and path data

The
[`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)
one-call helper attaches
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
output as a `text_runs` attribute on its result, so downstream consumers
that want to label paths with nearby text have everything they need in
one object. See the
[extracting-paths](https://humanpred.github.io/rpdfium/articles/extracting-paths.md)
vignette for the schema.

## Cleanup

``` r

pdf_close_page(page)
pdf_close(doc)
```
