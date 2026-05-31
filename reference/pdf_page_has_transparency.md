# Does the page contain transparency?

Wraps `FPDFPage_HasTransparency`. Returns `TRUE` if any page object on
`page` uses alpha blending or a transparency group. PDFium needs this
hint when laying out the rendering pipeline; downstream analyses (e.g.
flattening to opaque colors) also care.

## Usage

``` r
pdf_page_has_transparency(page)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md).

## Value

Logical scalar.
