# Report the type of a page object

Report the type of a page object

## Usage

``` r
pdf_obj_type(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md).

## Value

Character scalar: one of `"path"`, `"text"`, `"image"`, `"form"`,
`"shading"`, or `"unknown"`.
