# Remove a content-mark parameter

Wraps `FPDFPageObjMark_RemoveParam`. Removes the entry with `key` from
the mark identified by `mark_index` (one-based, per
[`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md)).

## Usage

``` r
pdf_obj_mark_remove_param(obj, mark_index, key)
```

## Arguments

- obj:

  A `pdfium_obj`.

- mark_index:

  One-based index of the mark.

- key:

  Character scalar — the parameter key to remove.

## Value

Invisibly returns the parent `pdfium_doc`.
