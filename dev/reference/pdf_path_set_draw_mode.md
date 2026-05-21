# Set the draw mode of a path page object

Wraps `FPDFPath_SetDrawMode`. Controls whether the path is filled,
stroked, or both.

## Usage

``` r
pdf_path_set_draw_mode(obj, fill_mode, stroke)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- fill_mode:

  Character scalar; one of `"none"`, `"even_odd"` (the PDF even-odd /
  alternate rule), or `"winding"` (the non-zero winding rule). Matches
  [`pdf_path_draw_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_draw_mode.md)'s
  `fill_mode` column.

- stroke:

  Logical scalar.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_draw_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_draw_mode.md).
