# Does a page object use alpha blending?

Returns `TRUE` when PDFium reports that the page object contributes any
alpha (a fill or stroke colour with alpha \< 255, an embedded image with
an alpha or soft-mask channel, a Form XObject containing transparency,
etc.). Wraps `FPDFPageObj_HasTransparency`.

## Usage

``` r
pdf_obj_has_transparency(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of any type from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

## Value

Logical scalar.
