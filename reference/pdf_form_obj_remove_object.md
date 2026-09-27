# Remove a child page-object from a form-xobject

Wraps `FPDFFormObj_RemoveObject` + `FPDFPageObj_Destroy`. The child must
currently belong to the form-xobject. PDFium hands the removed child
back to the caller, so it is destroyed straight away and the `child`
handle is closed: further calls on it error cleanly. Other handles to
the child (and, when the child is itself a form, to its own children)
are stale and must not be used; call
[`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
again for the remaining children.

## Usage

``` r
pdf_form_obj_remove_object(form_obj, child)
```

## Arguments

- form_obj:

  A `pdfium_obj` of `type = "form"`. Parent doc must be readwrite.

- child:

  A `pdfium_obj` from
  [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
  (the enumeration of children).

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

The removal changes the page in memory, so rendering and
[`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
reflect it, but PDFium does not write it back into the form XObject:
when the page is saved, the regenerated form content goes to a
`/Contents` entry that PDF readers ignore, and the saved file still
draws the removed child.
