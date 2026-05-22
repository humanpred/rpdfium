# Close an XObject handle

Wraps `FPDF_CloseXObject`. Idempotent. Closing the XObject does NOT
invalidate page-objects created from it via
[`pdf_obj_form_from_xobject()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_form_from_xobject.md)
— those are owned by their parent page and survive the XObject's
release.

## Usage

``` r
pdf_xobject_close(xobject)
```

## Arguments

- xobject:

  A `pdfium_xobject` from
  [`pdf_xobject_from_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_xobject_from_page.md).

## Value

Invisibly returns `xobject`.
