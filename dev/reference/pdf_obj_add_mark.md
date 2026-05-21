# Add a content mark to a page object

Wraps `FPDFPageObj_AddMark`. Content marks tag the object for downstream
consumers (the structure tree, custom workflows). Optional `params` are
written via `FPDFPageObjMark_SetIntParam` or `_SetStringParam` depending
on each value's R type.

## Usage

``` r
pdf_obj_add_mark(obj, name, params = list())
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).
  Parent doc must be readwrite.

- name:

  Character scalar — the mark's name (e.g. `"Span"`, `"Artifact"`,
  `"MCID"`).

- params:

  Optional named list of integer- or character-typed parameter values to
  attach to the mark. Numeric values are coerced to integer; character
  values are written as strings. Other types raise an error.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md),
[`pdf_obj_remove_mark()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_remove_mark.md).
