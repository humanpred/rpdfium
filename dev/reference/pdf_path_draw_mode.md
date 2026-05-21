# Path draw mode (fill rule + stroke flag)

Returns whether a path object is stroked and which fill mode is applied.
A path can be:

## Usage

``` r
pdf_path_draw_mode(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`.

## Value

A named list with two elements:

- `fill_mode` - one of `"none"`, `"even_odd"`, `"winding"`. `NA` if
  PDFium reports no draw-mode (rare; typically only on malformed paths).

- `fill_mode_code` - the raw integer code (`0`, `1`, `2`) for
  round-tripping with v0.2.0 writers.

- `stroke` - logical scalar; `TRUE` if the path is stroked.

## Details

- Stroked only (`stroke = TRUE`, `fill_mode = "none"`).

- Filled with non-zero winding rule (`fill_mode = "winding"`).

- Filled with even-odd rule (`fill_mode = "even_odd"`).

- Both stroked and filled (`stroke = TRUE` + `fill_mode != "none"`).

- Invisible (`stroke = FALSE`, `fill_mode = "none"`) — used for
  clip-only paths.

Wraps `FPDFPath_GetDrawMode`.

## See also

[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_stroke.md)
for the stroke color/width;
[`pdf_path_fill()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_fill.md)
for the fill color.
