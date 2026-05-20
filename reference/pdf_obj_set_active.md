# Set whether a page object renders

Wraps `FPDFPageObj_SetIsActive`. When `FALSE`, the object stays in the
page's content stream but is skipped during render and export. Useful
for soft-hiding annotations or watermarks without deleting them.

## Usage

``` r
pdf_obj_set_active(obj, active)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md).
  Parent doc must be readwrite.

- active:

  Logical scalar.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_obj_is_active()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_is_active.md)
for the read side.
