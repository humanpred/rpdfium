# Active flag of a page object

Returns the PDFium "is active" flag. Inactive page objects are still
enumerated by
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
but PDFium skips them when rendering or measuring extents. Wraps
`FPDFPageObj_GetIsActive`.

## Usage

``` r
pdf_obj_is_active(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of any type from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

## Value

Logical scalar (`TRUE` / `FALSE`), or `NA` when PDFium reports failure
(very rare).
