# Read all segments of a clip path as a tibble

Returns a data frame describing every segment in every sub-path of
`clip_path`, ordered first by `path_index` and then by `seg_index`
within each sub-path. Mirrors the shape of
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
but adds a `path_index` column for the clip's outer level. Wraps
`FPDFClipPath_CountPaths`, `FPDFClipPath_CountPathSegments`, and
`FPDFClipPath_GetPathSegment`.

## Usage

``` r
pdf_clip_path_segments(clip_path)
```

## Arguments

- clip_path:

  A `pdfium_clip_path` from
  [`pdf_obj_clip_path()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_clip_path.md).

## Value

A tibble with columns:

- `path_index` integer - 1-based sub-path index within the clip

- `segment_index` integer - 1-based segment index within its sub-path

- `segment_type` character - `"moveto"`, `"lineto"`, `"bezierto"`, or
  `"unknown"`

- `x`, `y` numeric - segment coordinates in PDF user space

- `close_figure` logical - whether this segment closes its sub-path

## Details

Coordinates are in PDF user space (typically points, with the origin at
the page's bottom-left).

## See also

[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
for the same shape applied to a regular page object's path.
