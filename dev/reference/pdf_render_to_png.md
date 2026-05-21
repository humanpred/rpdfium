# Render a PDF page directly to a PNG file

Convenience wrapper that calls
[`pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md)
and writes the result via
[`png::writePNG()`](https://rdrr.io/pkg/png/man/writePNG.html). The
`png` package is required at runtime (it's a Suggests dependency).

## Usage

``` r
pdf_render_to_png(
  page,
  file,
  page_num = 1L,
  dpi = 72,
  background = "white",
  annotations = FALSE,
  rotation = 0L
)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc` (the page given by `page_num` will be loaded and
  closed internally).

- file:

  Output file path.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

- dpi:

  Render resolution in dots per inch (default `72`, meaning one pixel
  per PDF point). Higher values give larger, sharper output at
  proportional memory cost.

- background:

  Background color drawn behind the page content before rendering.
  Accepts any string
  [`grDevices::col2rgb()`](https://rdrr.io/r/grDevices/col2rgb.html)
  understands (named color, `"#RRGGBB"`, `"#RRGGBBAA"`), or `NA` for a
  fully transparent background. Defaults to `"white"`.

- annotations:

  Logical; render annotation appearance streams on top of the page
  content. Defaults to `FALSE`.

- rotation:

  Extra rotation in degrees applied on top of the page's own `/Rotate`
  attribute. One of `0`, `90`, `180`, `270`. Note: PDFium's rotation is
  clockwise; e.g. `90` means rotate the page 90° clockwise from its
  on-page orientation.

## Value

Invisibly returns `file`.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture) && requireNamespace("png", quietly = TRUE)) {
  out <- tempfile(fileext = ".png")
  pdf_render_to_png(pdf_doc_open(fixture), file = out, dpi = 96)
  file.exists(out)
}
#> [1] TRUE
```
