# Append a sequence of path segments in one call

Convenience wrapper that takes a tibble in the shape
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md)
returns and replays it as a series of appender calls on `obj`. Useful
when you've read a path with
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md),
edited the rows in R, and want to append the modified geometry to a
fresh path object.

## Usage

``` r
pdf_path_append(obj, segments)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- segments:

  A tibble with at minimum the columns `segment_type` (character), `x`,
  `y` (numeric), and optionally `close_figure` (logical). Matches the
  [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md)
  output exactly so a reader → edit → writer round-trip is a one-liner.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Segment dispatch by the `segment_type` column:

- `"moveto"` →
  [`pdf_path_move_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_move_to.md)
  with `(x, y)`.

- `"lineto"` →
  [`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_to.md)
  with `(x, y)`.

- `"bezierto"` → cubic Bezier. PDFium's reader surfaces each cubic curve
  as **three** consecutive `bezierto` rows (two control points then the
  endpoint); this wrapper buffers two rows and emits a single
  [`pdf_path_bezier_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_bezier_to.md)
  call on the third.

Any row whose `close_figure` column is `TRUE` triggers a
[`pdf_path_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_close.md)
after its segment.

## See also

[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md).
