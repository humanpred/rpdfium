# Remove a content mark from a page object

Wraps `FPDFPageObj_RemoveMark`. `mark_index` is 1-based and matches the
row order
[`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md)
returns; removing a mark shifts every subsequent mark's index down by
one.

## Usage

``` r
pdf_obj_remove_mark(obj, mark_index)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).
  Parent doc must be readwrite.

- mark_index:

  One-based index of the mark to remove.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md),
[`pdf_obj_add_mark()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_add_mark.md).
