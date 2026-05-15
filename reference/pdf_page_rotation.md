# Page rotation in degrees

Returns the page's rotation as `0`, `90`, `180`, or `270` degrees.
PDFium reports the rotation stored in the page's `/Rotate` entry
combined with any runtime rotation applied via the editing API.

## Usage

``` r
pdf_page_rotation(x, page = 1L)
```

## Arguments

- x:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc`.

- page:

  One-based page index. Only used when `x` is a `pdfium_doc`. Ignored
  otherwise.

## Value

An integer in `{0, 90, 180, 270}`.

## Details

A non-zero rotation means
[`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)'s
`width` and `height` refer to the page's pre-rotation media box, not the
on-screen dimensions a viewer would display. For an "as-displayed" size,
swap `width` and `height` when rotation is `90` or `270`.

## See also

[`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)
for the un-rotated dimensions.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
                       package = "pdfium")
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  pdf_page_rotation(doc, 1)
  pdf_close(doc)
}
```
