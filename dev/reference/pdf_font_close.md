# Close a font handle

Releases the underlying PDFium font. Idempotent — a second call is a
no-op. The finalizer attached to the externalptr also runs this when R
garbage-collects the `pdfium_font`, but explicit close is useful when
many large fonts have been loaded and you want deterministic release.

## Usage

``` r
pdf_font_close(font)
```

## Arguments

- font:

  A `pdfium_font` from
  [`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_standard.md)
  or
  [`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md).

## Value

Invisibly returns `font`.

## Details

Closing a font does **not** invalidate text objects that already used it
— PDFium keeps an internal reference. Only the embedder's R-side handle
is released.
