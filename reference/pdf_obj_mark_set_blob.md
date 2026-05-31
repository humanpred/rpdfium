# Set a binary-blob content-mark parameter

Wraps `FPDFPageObjMark_SetBlobParam`. The mark-name + key locate an
entry in the page object's marked-content dictionary; the `value` raw
vector becomes the entry's binary blob.

## Usage

``` r
pdf_obj_mark_set_blob(obj, mark_index, key, value)
```

## Arguments

- obj:

  A `pdfium_obj`.

- mark_index:

  One-based index of the mark (per
  [`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_marks.md)).

- key:

  Character scalar — the parameter key within the mark.

- value:

  Raw vector — the blob bytes.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

Use
[`pdf_obj_mark_remove_param()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_mark_remove_param.md)
for the inverse.
