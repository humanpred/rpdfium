# Share an existing content mark with another page object

Wraps `FPDFPageObj_AddExistingMark`: appends mark number `mark_index` of
`src` to `obj`'s mark stack. Unlike
[`pdf_obj_add_mark()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_add_mark.md),
which creates a fresh mark, the mark is **shared by reference**: both
objects hold the same mark, so a parameter edited through either object
(e.g. with
[`pdf_obj_mark_set_blob()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_mark_set_blob.md)
or
[`pdf_obj_mark_remove_param()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_mark_remove_param.md))
is visible from both. When the page content is regenerated, consecutive
page objects that share a mark are written inside a single
marked-content sequence (one `BDC` ... `EMC` pair); this is how to tag
several objects as one logical span, e.g. one structure element's
`MCID`.

## Usage

``` r
pdf_obj_add_existing_mark(obj, src, mark_index)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md).
  Parent doc must be readwrite.

- src:

  A `pdfium_obj` carrying the mark, from the same document as `obj` (it
  may be `obj` itself or live on another page).

- mark_index:

  One-based index of the mark within `src`, as reported by
  [`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_marks.md).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_marks.md),
[`pdf_obj_add_mark()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_add_mark.md),
[`pdf_obj_remove_mark()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_remove_mark.md).
