# Read a page's bounding box

PDF pages can carry up to five named boxes:
[MediaBox](https://www.iso.org/standard/63534.html) (physical page
extent), CropBox (visible / printable extent), BleedBox (printer trim
with bleed), TrimBox (final page after cutting), and ArtBox (meaningful
content).
[`pdf_page_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_size.md)
returns the MediaBox's width/height; this function returns any of the
five boxes as a `(left, bottom, right, top)` named vector.

## Usage

``` r
pdf_page_box(
  page,
  page_num = 1L,
  box = c("media", "crop", "bleed", "trim", "art")
)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

- box:

  One of `"media"` (default), `"crop"`, `"bleed"`, `"trim"`, `"art"`.

## Value

A named numeric vector with elements `left`, `bottom`, `right`, `top`
(PDF user-space points). Every element is `NA` when the requested box is
not declared on the page. Note that per the PDF spec a viewer falls back
from a missing CropBox / BleedBox / TrimBox / ArtBox to the MediaBox,
but `pdf_page_box()` does not - if you want the "what would render"
rectangle, call `pdf_page_box()` for `"media"` after testing whether a
more specific box exists.

## Details

Wraps `FPDFPage_GetMediaBox` / `_GetCropBox` / `_GetBleedBox` /
`_GetTrimBox` / `_GetArtBox`.

## See also

[`pdf_page_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_size.md)
(always MediaBox width/height).
