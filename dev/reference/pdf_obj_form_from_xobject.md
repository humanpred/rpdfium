# Instantiate an XObject as a form page-object on a page

Wraps `FPDF_NewFormObjectFromXObject` + `FPDFPage_InsertObject`. Creates
a fresh form-xobject page-object referencing the shared XObject content
and inserts it on `page`. The page-object can then be transformed /
placed via the usual
[`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_matrix.md)
setter.

## Usage

``` r
pdf_obj_form_from_xobject(page, xobject)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_new.md)
  or
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md)
  (parent doc must be readwrite).

- xobject:

  A `pdfium_xobject` from
  [`pdf_xobject_from_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_xobject_from_page.md).
  The XObject must have been created against the same `dest_doc` that
  owns `page`.

## Value

The new `pdfium_obj` (type `"form"`).

## See also

[`pdf_xobject_from_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_xobject_from_page.md).
