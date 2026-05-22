# Remove a child page-object from a form-xobject

Wraps `FPDFFormObj_RemoveObject`. The child must currently belong to the
form-xobject. After removal the child's R-side externalptr is unchanged
(PDFium destroys the child internally); calling other setters on the
same handle will error cleanly via the existing `is_open()` chain
because PDFium's pointer is no longer valid.

## Usage

``` r
pdf_form_obj_remove_object(form_obj, child)
```

## Arguments

- form_obj:

  A `pdfium_obj` of `type = "form"`.

- child:

  A `pdfium_obj` from
  [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_objects.md)
  (the enumeration of children).

## Value

Invisibly returns the parent `pdfium_doc`.
