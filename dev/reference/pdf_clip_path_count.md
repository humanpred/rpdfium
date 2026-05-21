# Count sub-paths in a clip path

Wraps `FPDFClipPath_CountPaths`. A clip path can consist of multiple
sub-paths (e.g. a union of rectangles); this returns how many.

## Usage

``` r
pdf_clip_path_count(clip_path)
```

## Arguments

- clip_path:

  A `pdfium_clip_path` from
  [`pdf_obj_clip_path()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_clip_path.md).

## Value

Integer scalar.
