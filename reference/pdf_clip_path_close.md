# Release a clip-path handle

Wraps `FPDF_DestroyClipPath`. Idempotent — a second call is a no-op. The
finalizer attached to the externalptr also runs this when R
garbage-collects the handle; explicit close is useful when you've
created many clip paths and want deterministic release.

## Usage

``` r
pdf_clip_path_close(clip_path)
```

## Arguments

- clip_path:

  A `pdfium_clip_box` from
  [`pdf_clip_path_new()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_new.md).

## Value

Invisibly returns `clip_path`.
